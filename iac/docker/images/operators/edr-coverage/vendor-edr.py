"""Export EDR agents to {company}_edr.csv.

Replaces a manual export: *_edr.csv used to be dropped in by hand. The API is
OAuth2 password + cursor pagination on /api/v1/agents/list-v2 (see the tenant swagger).

Several companies often share one tenant and the same credentials — the list is
fetched once per (url, username) and the same CSV is written for each company
in the group, instead of hitting the API once per company.

Config: EDR_CONFIG_DIR/edr_config.json (defaults to the current directory):
  {"<company>": {"username": "", "password": "",
                 "url": "https://<tenant>.edr.example.com:8080", "use_proxy": false}}

The proxy (use_proxy=true) is taken from EDR_PROXY_URL — unlike the old script
the address is not hardcoded. The monitoring VM talks to the EDR vendor
directly, so use_proxy=false there.
"""

import collections
import json
import logging
import os
import re
import sys
from pathlib import Path

import pandas as pd
import requests
import urllib3
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

log = logging.getLogger("vendor_edr")

DATA_DIR = Path(os.environ.get("EDR_DATA_DIR", "."))
CONFIG_DIR = Path(os.environ.get("EDR_CONFIG_DIR", "."))
CONFIG_PATH = CONFIG_DIR / "edr_config.json"
REQUEST_TIMEOUT = int(os.environ.get("EDR_API_TIMEOUT", "60"))
PROXY_URL = os.environ.get("EDR_PROXY_URL", "")

# Local domains to strip from hostname so names match cloud/AD inventory.
# The sensor console sometimes returns an FQDN.
LOCAL_DOMAIN_SUFFIXES = [
    s.strip().lower()
    for s in os.environ.get(
        "EDR_STRIP_SUFFIXES",
        ".ru-central1.internal,.novalocal,.example.com",
    ).split(",")
    if s.strip()
]

# Final CSV columns (what merge3 and the freshness metric read). Order and
# lowercase match historical exports so nothing drifts.
OUTPUT_COLUMNS = [
    "id", "name", "displayname", "domain", "os", "osname", "osversion", "sourceip",
    "isauthorized", "version", "isonline", "versionstatus", "lastseenat",
    "registeredat", "lastuser", "inv_hostname", "mac",
]

# Enrich records from /agents/{id}: list-v2 does not return these fields.
#   disputed (default) — only disputed records whose name does not identify
#     a machine: name duplicates and truncated names. About 49 of 482; the
#     walk takes seconds. For them inventory.hostname restores the real name:
#     agents named '192' become m-proj-c-00026 and m-proj-c-00012.
#   all — every agent (~482 requests, about 30 seconds): needed if MAC is
#     used as a match key.
#   off — do not call detail at all.
ENRICH_MODE = os.environ.get("EDR_ENRICH", "disputed").strip().lower()

# A name of only digits and dots does not identify a machine: macOS puts the
# part before the first dot into the short name, so host 192.168.1.11 arrives as '192'.
NUMERIC_NAME = re.compile(r"^[\d.]+$")
# Agent fields from the API (camelCase) -> CSV column (lower). Missing keys
# are filled with empty values.
API_TO_CSV = {
    "id": "id", "name": "name", "displayName": "displayname",
    "domain": "domain", "os": "os",
    "osName": "osname", "osVersion": "osversion", "sourceIP": "sourceip",
    "isAuthorized": "isauthorized", "version": "version", "isOnline": "isonline",
    "versionStatus": "versionstatus", "lastSeenAt": "lastseenat",
    # agent registration time: a reinstalled agent has a fresh value, the old
    # record of the same host keeps the previous one — that marks a re-register.
    # NB: filled on only 74 of 482 agents, so it is not usable as a "dead
    # record" signal — there is nothing to measure.
    "registeredAt": "registeredat", "lastUser": "lastuser",
}

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        log.error("config missing: %s", CONFIG_PATH)
        sys.exit(1)
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def make_session(use_proxy: bool) -> requests.Session:
    session = requests.Session()
    # The sensor console sometimes tears the TLS handshake (UNEXPECTED_EOF) —
    # survive with retries and backoff instead of failing the whole vendor section.
    retry = Retry(total=4, backoff_factor=1.0,
                  status_forcelist=[429, 500, 502, 503, 504],
                  allowed_methods=["GET", "POST"])
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    if use_proxy:
        if not PROXY_URL:
            log.warning("use_proxy=true but EDR_PROXY_URL is unset — going direct")
        else:
            session.proxies = {"http": PROXY_URL, "https": PROXY_URL}
    return session


def get_token(session: requests.Session, url: str, username: str, password: str) -> str:
    resp = session.post(
        f"{url}/api/v1/oauth2/token",
        headers={"Accept": "application/json", "User-Agent": "sec-stack-edr-coverage/1.0"},
        data={"grant_type": "password", "username": username, "password": password},
        verify=False,
        timeout=REQUEST_TIMEOUT,
    )
    resp.raise_for_status()
    return resp.json()["access_token"]


def fetch_agents(session: requests.Session, url: str, token: str) -> list[dict]:
    """All tenant agents via cursor pagination on list-v2."""
    headers = {"Authorization": f"Bearer {token}"}
    agents, cursor = [], None
    while True:
        page_filter = {"sort": {"by": "name", "order": "ASC"}, "pagination": {"first": 1000}}
        if cursor:
            page_filter["pagination"]["after"] = cursor
        resp = session.post(
            f"{url}/api/v1/agents/list-v2",
            files={"filter": (None, json.dumps(page_filter))},
            headers=headers,
            verify=False,
            timeout=REQUEST_TIMEOUT,
        )
        resp.raise_for_status()
        data = resp.json()
        agents.extend(data.get("items") or [])
        page = data.get("pageInfo") or {}
        if not page.get("hasNextPage"):
            break
        cursor = page.get("endCursor")
        if not cursor:
            break
    return agents


def _match_key(name) -> str:
    """Name comparison key — same as merge3._norm_host (upper, '_' -> '-')."""
    return str(name or "").strip().upper().replace("_", "-")


def disputed_agents(agents: list[dict]) -> list[dict]:
    """
    Records whose name does not identify a machine: the name matches another
    agent (reinstall or collision) or is only digits and dots.
    These are exactly the records merge3 collapses in dedup or rejects in matching.
    """
    counts = collections.Counter(_match_key(a.get("name")) for a in agents)
    return [
        a for a in agents
        if counts[_match_key(a.get("name"))] > 1 or NUMERIC_NAME.match(_match_key(a.get("name")))
    ]


def fetch_agent_detail(session: requests.Session, url: str, token: str, agent_id: str) -> dict:
    """Agent card: inventory (hostname, network interfaces) is not in list-v2."""
    resp = session.get(
        f"{url}/api/v1/agents/{agent_id}",
        headers={"Authorization": f"Bearer {token}"},
        verify=False,
        timeout=REQUEST_TIMEOUT,
    )
    resp.raise_for_status()
    return resp.json()


def enrich_agents(session: requests.Session, url: str, token: str, agents: list[dict]) -> None:
    """
    Add inventory.hostname and MAC addresses from /agents/{id} onto agent records.

    Walk disputed agents only (see ENRICH_MODE): there are few of them, and
    those are the ones that cannot be trusted. A failure on one agent must not
    drop the export — the field stays empty, the same state as without enrich.
    """
    if ENRICH_MODE == "off":
        return
    targets = agents if ENRICH_MODE == "all" else disputed_agents(agents)
    if not targets:
        return

    failed = 0
    for agent in targets:
        try:
            inventory = fetch_agent_detail(session, url, token, agent["id"]).get("inventory") or {}
        except Exception as exc:
            failed += 1
            log.debug("detail for agent %s not received: %s", agent.get("id"), exc)
            continue
        agent["invHostname"] = (inventory.get("hostname") or "").strip()
        macs = {
            str(iface.get("mac")).strip().lower()
            for iface in (inventory.get("networkInterfaces") or [])
            if iface.get("mac")
        }
        agent["macs"] = ",".join(sorted(macs))

    recovered = sum(
        1 for a in targets
        if a.get("invHostname") and _match_key(a["invHostname"]) != _match_key(a.get("name"))
    )
    log.info("enriched records: %d of %d (mode %s), name restored for %d, no reply %d",
             len(targets) - failed, len(agents), ENRICH_MODE, recovered, failed)


def normalize_name(name, comment) -> str:
    """Hostname: comment beats name (EDR vendor support fixes bad FQDNs),
    strip the local domain, uppercase.

    NB (checked on the live API 2026-08-12): /agents/list-v2 has no comment
    field at all — a non-empty comment on 0 of 482 agents; it lives only on
    /agents/{id}. The comment branch stays in case the console starts returning
    it, but the actual name now always comes from name. The API itself can
    already return a truncated name: macOS puts the part before the first dot
    into the short name, so a host with network name 192.168.1.11 arrives as
    '192'. The full name is in displayName — exported as a separate column.
    """
    comment = str(comment or "").strip()
    base = comment if comment and comment.lower() not in ("nan", "none") else str(name or "").strip()
    low = base.lower()
    for suffix in LOCAL_DOMAIN_SUFFIXES:
        if low.endswith(suffix):
            base = base[: -len(suffix)]
            break
    return base.upper()


def agents_to_df(agents: list[dict]) -> pd.DataFrame:
    rows = []
    for a in agents:
        row = {csv_col: a.get(api_key, "") for api_key, csv_col in API_TO_CSV.items()}
        row["name"] = normalize_name(a.get("name"), a.get("comment"))
        # filled only on enriched records (see enrich_agents)
        row["inv_hostname"] = a.get("invHostname", "")
        row["mac"] = a.get("macs", "")
        rows.append(row)
    df = pd.DataFrame(rows, columns=OUTPUT_COLUMNS)
    # timestamps as YYYY-MM-DD HH:MM:SS (same as historical exports)
    for col in ("lastseenat", "registeredat"):
        ts = pd.to_datetime(df[col], errors="coerce", utc=True)
        df[col] = ts.dt.tz_localize(None).dt.strftime("%Y-%m-%d %H:%M:%S")
    return df


def main():
    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
        stream=sys.stderr,
    )
    config = load_config()

    # Group companies by (url, username): one tenant — one API request.
    groups: dict[tuple, list[str]] = {}
    creds: dict[tuple, dict] = {}
    for company, cfg in config.items():
        key = (cfg["url"], cfg["username"])
        groups.setdefault(key, []).append(company)
        creds[key] = cfg

    failures = 0
    for (url, username), companies in groups.items():
        cfg = creds[(url, username)]
        try:
            session = make_session(cfg.get("use_proxy", False))
            token = get_token(session, url, username, cfg["password"])
            agents = fetch_agents(session, url, token)
            enrich_agents(session, url, token, agents)
            df = agents_to_df(agents)
            for company in companies:
                out = DATA_DIR / f"{company}_edr.csv"
                df.to_csv(out, index=False, encoding="utf-8")
            log.info("tenant %s: agents %d -> %s",
                     url.split("//")[-1].split(".")[0], len(df),
                     ", ".join(f"{c}_edr.csv" for c in companies))
        except Exception:
            failures += 1
            log.exception("tenant %s (%s): export failed",
                          url, ", ".join(companies))

    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
