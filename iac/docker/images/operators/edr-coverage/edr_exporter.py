#!/usr/bin/env python3
"""Prometheus exporter for EDR coverage.

Serves coverage metrics from merge3: aggregates by company/host type and
per-host detail (which machines have no agent).

The pipeline talks to LDAP and cloud APIs — that takes minutes, so it cannot
run on every scrape. Collection runs on a background thread every
EDR_COLLECT_INTERVAL, and /metrics instantly returns the last snapshot: the
VictoriaMetrics series stays continuous, and external sources are polled rarely.

  EDR_DATA_DIR         directory with CSV and results (see merge3.DATA_DIR)
  EDR_CONFIG_DIR       collector config directory (read-only, from SOPS)
  EDR_COLLECT_SOURCES  1 (default) — run collectors; 0 — merge CSV only
  EDR_LISTEN           HTTP server address, default 0.0.0.0:9655
  EDR_COLLECT_INTERVAL recalculation period in seconds, default 6 hours
  EDR_WATCH_INTERVAL   how often to check source CSV mtime, default 60s

--oneshot: compute once, print metrics to stdout, and exit.
"""

import argparse
import importlib.util
import logging
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pandas as pd
from prometheus_client import CONTENT_TYPE_LATEST, CollectorRegistry, Gauge, generate_latest

import merge3

log = logging.getLogger("edr_exporter")

LISTEN = os.environ.get("EDR_LISTEN", "0.0.0.0:9655")
COLLECT_INTERVAL = int(os.environ.get("EDR_COLLECT_INTERVAL", str(6 * 3600)))
WATCH_INTERVAL = int(os.environ.get("EDR_WATCH_INTERVAL", "60"))
CONFIG_DIR = Path(os.environ.get("EDR_CONFIG_DIR", "."))
COLLECT_SOURCES = os.environ.get("EDR_COLLECT_SOURCES", "1") not in ("0", "false", "no", "")

# Source collectors: (section, script file, config whose presence enables
# collection). Scripts with a hyphen in the name are imported by path
# (a normal import cannot).
COLLECTORS = [
    ("active_directory", "active-directory.py", "ad_config.yaml"),
    ("vkcloud", "vkcloud.py", "vkcloud_config.yaml"),
    ("sbercloud", "sbercloud-adv.py", "sbc-adv_config.yaml"),
    ("vendor", "vendor-edr.py", "edr_config.json"),
]

# Source-file suffix -> source label value. Order matters: '_edr' is checked
# first, otherwise '-ad' cannot be told apart from other exports.
SOURCE_SUFFIXES = [
    ("_edr", "edr"),
    ("-ad", "ad"),
    ("-vkcloud", "vkcloud"),
    ("-sbc-adv", "sbercloud"),
]


def _source_kind(stem: str) -> tuple[str, str] | None:
    """('project-a-ad') -> ('project-a', 'ad'); None for unknown files."""
    for suffix, kind in SOURCE_SUFFIXES:
        if stem.endswith(suffix):
            return stem[: -len(suffix)], kind
    return None


def source_files() -> dict[tuple[str, str], float]:
    """{(company, source): mtime} for all source CSVs in the data directory."""
    result = {}
    for path in merge3.DATA_DIR.glob("*.csv"):
        if path.name == merge3.OUTPUT_CSV.name:
            continue
        parsed = _source_kind(path.stem)
        if parsed:
            result[parsed] = path.stat().st_mtime
    return result


def edr_export_times() -> dict[str, float]:
    """
    {company: export unix time} from the lastseenat column of *_edr.csv.

    File age is not usable: the export is dropped in by hand, and a normal
    scp/copy resets mtime to "now" — the freshness metric then lies exactly
    where it is needed. Max lastseenat is taken from the data: at least one
    agent is almost always online, so it is close to the export moment and
    does not depend on how the file arrived.
    """
    result = {}
    for path in merge3.DATA_DIR.glob("*_edr.csv"):
        company = path.stem[: -len("_edr")]
        try:
            column = pd.read_csv(path, usecols=["lastseenat"])["lastseenat"]
            latest = pd.to_datetime(column, errors="coerce", utc=True).max()
        except Exception:
            log.warning("[%s] could not determine EDR export time", company)
            continue
        if pd.notna(latest):
            result[company] = latest.timestamp()
    return result


class Snapshot:
    """Last successfully computed result, served on every scrape."""

    def __init__(self):
        self._lock = threading.Lock()
        self._body = b""
        self.collected_at = 0.0

    def render(self, frame, overall, duration, errors):
        registry = CollectorRegistry()

        def gauge(name, doc, labels=()):
            return Gauge(name, doc, labels, registry=registry)

        collect_errors = gauge("edr_collect_errors", "1 if the collect section failed", ["section"])
        for section, failed in errors.items():
            collect_errors.labels(section).set(int(failed))

        gauge("edr_collection_duration_seconds", "Duration of the last collection").set(duration)

        source_ts = gauge(
            "edr_source_file_timestamp_seconds",
            "Unix time of the last source-file change",
            ["company", "source"],
        )
        for (company, source), mtime in source_files().items():
            source_ts.labels(company, source).set(mtime)

        export_ts = gauge(
            "edr_source_data_timestamp_seconds",
            "Unix time of the export from data inside it (not file mtime)",
            ["company", "source"],
        )
        for company, ts in edr_export_times().items():
            export_ts.labels(company, "edr").set(ts)

        if overall:
            hosts_total = gauge(
                "edr_hosts_total", "Hosts in the counting pool", ["company", "host_type"]
            )
            hosts_with_agent = gauge(
                "edr_hosts_with_agent", "Hosts with an EDR agent", ["company", "host_type"]
            )
            hosts_online = gauge(
                "edr_hosts_agent_online", "Hosts with an agent in contact", ["company", "host_type"]
            )
            hosts_excluded = gauge(
                "edr_hosts_excluded", "Hosts excluded by exclusion rules", ["company"]
            )
            # Agents not matched to any host. The only signal that an inventory
            # source is missing entirely: coverage still looks fine because it
            # is counted on the hosts that are visible.
            # Tenant-level number: companies on a shared tenant share it.
            agents_without_inventory = gauge(
                "edr_agents_without_inventory",
                "EDR agents without a host in inventory (per tenant)",
                ["company"],
            )
            # Managed nodes (DB, kubernetes) cannot take an agent and are out
            # of coverage. Shown as a count, not hidden: a host silently
            # dropped from the denominator must not happen in a coverage metric.
            hosts_managed = gauge(
                "edr_hosts_managed",
                "Hosts excluded as a managed service (agent impossible)",
                ["company", "managed_type"],
            )
            managed_rows = frame[frame[merge3.MANAGED_COL] != ""]
            for (company, kind), count in (
                managed_rows.groupby([merge3.COMPANY_COL, merge3.MANAGED_COL]).size().items()
            ):
                hosts_managed.labels(company, kind).set(count)
            # Percents are not exported: Grafana computes them from counters,
            # otherwise a multi-company aggregate would have to be averaged wrongly.
            for company, m in overall["COMPANIES"].items():
                for host_type, key in (("server", "SERVERS"), ("workstation", "WORKSTATIONS")):
                    hosts_total.labels(company, host_type).set(m[key]["VM_TOTAL"])
                    hosts_with_agent.labels(company, host_type).set(m[key]["EDR_VM_TOTAL"])
                    hosts_online.labels(company, host_type).set(m[key]["EDR_VM_ONLINE"])
                hosts_excluded.labels(company).set(m.get("EXCLUDED", 0))
                agents_without_inventory.labels(company).set(
                    m.get("AGENTS_WITHOUT_INVENTORY", 0)
                )

            installed = gauge(
                "edr_host_agent_installed",
                "EDR agent found on the host",
                ["company", "hostname", "host_type"],
            )
            online = gauge(
                "edr_host_agent_online",
                "EDR agent on the host is in contact",
                ["company", "hostname", "host_type"],
            )
            last_seen = gauge(
                "edr_host_agent_last_seen_seconds",
                "Unix time of last agent contact (for the silence window; hosts with an agent only)",
                ["company", "hostname", "host_type"],
            )
            # Pool hosts only: excluded ones must not enter lists or counters,
            # or the dashboard would diverge from the aggregates.
            for row in frame[frame["in_pool"]].itertuples():
                labels = (row.company, row.hostname, row.source_type)
                installed.labels(*labels).set(int(bool(row.has_edr)))
                online.labels(*labels).set(int(bool(row.edr_online)))
                ls = getattr(row, "edr_last_seen", float("nan"))
                if ls == ls:  # not NaN — agent exists and last-seen is known
                    last_seen.labels(*labels).set(float(ls))

            gauge(
                "edr_collection_timestamp_seconds", "Unix time of the last successful collection"
            ).set(time.time())

        body = generate_latest(registry)
        with self._lock:
            self._body = body
            self.collected_at = time.time()

    def body(self):
        with self._lock:
            return self._body


def _load_module(name, filename):
    path = Path(__file__).resolve().parent / filename
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run_collectors() -> dict:
    """Run source collectors before merge. Returns {section: failed}.

    Each collector is its own section: a failure in one (stale token, DC down)
    does not drop the others, the previous CSV of that source stays, and the
    error flag is raised in edr_collect_errors{section}. A source without a
    config is skipped — that is not an error (e.g. SberCloud before creds).
    """
    errors = {}
    if not COLLECT_SOURCES:
        return errors
    for section, filename, config_name in COLLECTORS:
        configured = (CONFIG_DIR / config_name).exists()
        if section == "vkcloud" and not configured:
            configured = bool(os.environ.get("VKC_USERNAME"))
        if not configured:
            continue
        try:
            log.info("collecting source: %s", section)
            _load_module(section, filename).main()
            errors[section] = False
        except Exception:
            log.exception("source collect %s failed", section)
            errors[section] = True
    return errors


def collect(snapshot):
    """Full pipeline run: write artifacts and refresh the snapshot."""
    started = time.time()
    errors = run_collectors()

    try:
        frame, overall = merge3.build_report()
        errors["merge"] = False
    except Exception:
        log.exception("collect failed")
        errors["merge"] = True
        snapshot.render(None, {}, time.time() - started, errors)
        return

    duration = time.time() - started
    snapshot.render(frame, overall, duration, errors)

    if not frame.empty:
        try:
            frame.to_csv(merge3.OUTPUT_CSV, index=False, encoding="utf-8")
        except Exception:
            log.exception("failed to write %s", merge3.OUTPUT_CSV)
        log.info(
            "collect in %.1fs: hosts %d, with agent %d (%.1f%%)",
            duration,
            overall["VM_TOTAL"],
            overall["EDR_VM_TOTAL"],
            overall["EDR_COVERAGE_PCT"],
        )


def collect_loop(snapshot):
    """Recalculate on a schedule; in manual mode also when CSV files change.

    IMPORTANT: watching source CSV mtime only makes sense when collectors are
    OFF (manual file drop). If collectors are on, they write those files
    themselves — watching would treat its own write as a change and loop
    forever every WATCH_INTERVAL (and hammer LDAP/clouds/EDR vendor).
    """
    last_mtimes = source_files()
    last_run = 0.0
    while True:
        due = time.time() - last_run >= COLLECT_INTERVAL
        changed = False
        if not COLLECT_SOURCES:
            mtimes = source_files()
            changed = mtimes != last_mtimes
            last_mtimes = mtimes
        if due or changed:
            if changed and not due:
                log.info("source files changed — recalculating")
            collect(snapshot)
            last_run = time.time()
        time.sleep(WATCH_INTERVAL)


class Handler(BaseHTTPRequestHandler):
    snapshot = None

    def log_message(self, fmt, *args):  # noisy default log — debug only
        log.debug(fmt, *args)

    def _respond(self, code, body, content_type="text/plain; charset=utf-8"):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/-/healthy":
            return self._respond(200, "ok\n")
        if self.path != "/metrics":
            return self._respond(404, "use /metrics\n")
        body = self.snapshot.body()
        if not body:
            # First collect is still running: 503 is more honest than an empty
            # body — vmagent marks the target down instead of recording zeros.
            return self._respond(503, "collecting, no snapshot yet\n")
        self._respond(200, body, CONTENT_TYPE_LATEST)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--oneshot", action="store_true", help="compute once, print metrics, and exit"
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
        stream=sys.stderr,
    )

    snapshot = Snapshot()

    if args.oneshot:
        collect(snapshot)
        sys.stdout.write(snapshot.body().decode())
        return

    threading.Thread(target=collect_loop, args=(snapshot,), daemon=True).start()

    Handler.snapshot = snapshot
    host, _, port = LISTEN.rpartition(":")
    server = ThreadingHTTPServer((host, int(port)), Handler)
    log.info("listening on %s, data from %s, recalculate every %ds",
             LISTEN, merge3.DATA_DIR.resolve(), COLLECT_INTERVAL)
    server.serve_forever()


if __name__ == "__main__":
    main()
