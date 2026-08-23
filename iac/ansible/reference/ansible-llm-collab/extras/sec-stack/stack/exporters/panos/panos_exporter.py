#!/usr/bin/env python3
"""Prometheus exporter for Palo Alto PAN-OS via the XML API.

Collects: HA state, IPsec SAs, license expiry, certificate expiry,
session-table usage.

Multi-target (like blackbox_exporter): GET /metrics?target=<fw-name-from-config>.
Each firewall API key is taken from the environment variable
PANOS_API_KEY_<NAME> (name upper-case, '-' -> '_'), or from PANOS_API_KEY.
"""

import logging
import os
import re
import sys
import time
import urllib.parse
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import requests
import urllib3
import yaml
from prometheus_client import CONTENT_TYPE_LATEST, CollectorRegistry, Gauge, generate_latest

log = logging.getLogger("panos_exporter")

CONFIG_PATH = os.environ.get("PANOS_EXPORTER_CONFIG", "/etc/panos-exporter/config.yml")
# Timeout of one PAN-OS API call; the panos job scrape_timeout must be larger
REQUEST_TIMEOUT = int(os.environ.get("PANOS_API_TIMEOUT", "15"))
# A one-off XML API error dropped the whole section: series vanished for one
# scrape, vmalert reset the alert and re-fired it -> false "cleared/firing".
# Budget: with scrape_timeout=50s one retry per call still fits
# (typical scrape ~10s, worst case with one retry ~26s).
API_RETRIES = int(os.environ.get("PANOS_API_RETRIES", "1"))
API_RETRY_DELAY = float(os.environ.get("PANOS_API_RETRY_DELAY", "1"))

# "June 30, 2027" (licenses); "Jun 30 12:00:00 2027 GMT" (certificates).
# TODO: compare with the actual output of the PAN-OS version in use and extend if needed.
LICENSE_DATE_FORMATS = ["%B %d, %Y", "%B %d %Y"]
CERT_DATE_FORMATS = ["%b %d %H:%M:%S %Y GMT", "%b %d %H:%M:%S %Y"]

CERT_XPATHS = [
    "/config/shared/certificate",
    "/config/devices/entry[@name='localhost.localdomain']/vsys/entry/certificate",
]

# IPsec tunnel role -> role label on panos_ipsec_tunnel_up. Only primary is
# alerted as critical; reserve (standby, expected down) and broken (known
# not-to-come-up) are visible on the dashboard but not sent to chat.
# Sources, in priority order:
#   1) ipsec_tunnel_roles in the exporter config.yml;
#   2) [sec-stack:role=reserve] marker in the tunnel comment on PAN-OS itself.
DEFAULT_TUNNEL_ROLE = "primary"
TUNNEL_ROLES = frozenset({"primary", "reserve", "broken"})
ROLE_COMMENT_RE = re.compile(r"\[sec-stack:role=([a-z-]+)\]", re.IGNORECASE)


def parse_date(value, formats):
    value = " ".join((value or "").split())
    for fmt in formats:
        try:
            return datetime.strptime(value, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None


class Firewall:
    def __init__(self, name, cfg):
        self.name = name
        self.host = cfg["host"]
        self.verify_tls = cfg.get("verify_tls", True)
        self.ignore_tunnels = set(cfg.get("ignore_ipsec_tunnels") or [])
        self.tunnel_roles = dict(cfg.get("ipsec_tunnel_roles") or {})
        key_env = cfg.get("api_key_env") or "PANOS_API_KEY_" + name.upper().replace("-", "_")
        self.api_key = os.environ.get(key_env) or os.environ.get("PANOS_API_KEY", "")
        if not self.api_key:
            log.warning("no API key for %s (expected variable %s)", name, key_env)
        if not self.verify_tls:
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        self.session = requests.Session()

    def _call(self, params):
        params = dict(params, key=self.api_key)
        for attempt in range(API_RETRIES + 1):
            try:
                return self._call_once(params)
            except Exception as exc:
                if attempt == API_RETRIES:
                    raise
                log.warning(
                    "[%s] API call failed (%s), retry %d/%d",
                    self.name, exc, attempt + 1, API_RETRIES,
                )
                time.sleep(API_RETRY_DELAY)

    def _call_once(self, params):
        resp = self.session.get(
            f"https://{self.host}/api/",
            params=params,
            timeout=REQUEST_TIMEOUT,
            verify=self.verify_tls,
        )
        resp.raise_for_status()
        root = ET.fromstring(resp.content)
        if root.get("status") != "success":
            raise RuntimeError(f"PAN-OS API error: {resp.text[:300]}")
        return root

    def tunnel_role(self, tunnel, comment=None):
        role = self.tunnel_roles.get(tunnel)
        if not role:
            match = ROLE_COMMENT_RE.search(comment or "")
            role = match.group(1).lower() if match else DEFAULT_TUNNEL_ROLE
        if role not in TUNNEL_ROLES:
            # fail-safe: unknown role = extra alert, not silence
            log.warning(
                "[%s] tunnel %s: unknown role %r, treating as %s (known: %s)",
                self.name, tunnel, role, DEFAULT_TUNNEL_ROLE, ", ".join(sorted(TUNNEL_ROLES)),
            )
            role = DEFAULT_TUNNEL_ROLE
        return role

    def op(self, cmd):
        return self._call({"type": "op", "cmd": cmd})

    def config_get(self, xpath):
        return self._call({"type": "config", "action": "get", "xpath": xpath})

    def config_show(self, xpath):
        # action=show reads running config (applied), get — candidate
        return self._call({"type": "config", "action": "show", "xpath": xpath})


class Collector:
    def __init__(self, fw):
        self.fw = fw
        self.registry = CollectorRegistry()
        self.errors = self._gauge(
            "panos_collect_errors", "1 if the collection section failed", ["section"]
        )

    def _gauge(self, name, doc, labels=()):
        return Gauge(name, doc, labels, registry=self.registry)

    def _section(self, name, func):
        try:
            func()
            self.errors.labels(name).set(0)
        except Exception:
            log.exception("[%s] section %s failed", self.fw.name, name)
            self.errors.labels(name).set(1)

    def collect(self):
        up = self._gauge("panos_up", "Firewall is reachable via XML API")
        try:
            root = self.fw.op("<show><system><info/></system></show>")
        except Exception:
            log.exception("[%s] unreachable", self.fw.name)
            up.set(0)
            return generate_latest(self.registry)
        up.set(1)

        info = self._gauge(
            "panos_info", "Device information", ["hostname", "serial", "sw_version"]
        )
        sysinfo = root.find("./result/system")
        if sysinfo is not None:
            info.labels(
                sysinfo.findtext("hostname") or "",
                sysinfo.findtext("serial") or "",
                sysinfo.findtext("sw-version") or "",
            ).set(1)

        self._section("ha", self.collect_ha)
        self._section("ipsec", self.collect_ipsec)
        self._section("licenses", self.collect_licenses)
        self._section("certificates", self.collect_certificates)
        self._section("sessions", self.collect_sessions)
        return generate_latest(self.registry)

    def collect_ha(self):
        root = self.fw.op("<show><high-availability><state/></high-availability></show>")
        enabled = (root.findtext("./result/enabled") or "").strip() == "yes"
        self._gauge("panos_ha_enabled", "HA is enabled on the device").set(int(enabled))
        if not enabled:
            return
        local = (root.findtext("./result/group/local-info/state") or "unknown").strip()
        peer = (root.findtext("./result/group/peer-info/state") or "unknown").strip()
        self._gauge(
            "panos_ha_state_info", "Current HA state", ["local_state", "peer_state"]
        ).labels(local, peer).set(1)
        self._gauge(
            "panos_ha_local_state_active", "1 if the local node is in active state"
        ).set(int(local == "active"))

    def collect_ipsec(self):
        root = self.fw.op("<show><vpn><ipsec-sa/></vpn></show>")
        # One record per SA; a tunnel with several proxy-ids has several.
        active = set()
        for entry in root.findall(".//entry"):
            name = entry.findtext("name")
            if name:
                # proxy-id is sometimes appended with ':' — normalize to tunnel name
                active.add(name.split(":")[0])

        # Tunnel list comes from the device running config — new ipsec
        # entries appear in monitoring on their own; no manual list.
        configured, disabled = set(), set()
        roles = {}
        conf = self.fw.config_show(
            "/config/devices/entry[@name='localhost.localdomain']/network/tunnel/ipsec"
        )
        # only direct entry: nested entry (proxy-id) sits deeper
        for entry in conf.findall("./result/ipsec/entry"):
            name = entry.get("name")
            if not name:
                continue
            if (entry.findtext("disabled") or "no").strip() == "yes":
                disabled.add(name)
            else:
                configured.add(name)
                roles[name] = self.fw.tunnel_role(name, entry.findtext("comment"))

        tunnel_up = self._gauge(
            "panos_ipsec_tunnel_up",
            "Tunnel has an active IPsec SA (tunnel list comes from device config)",
            ["tunnel", "role"],
        )
        for tunnel in configured - self.fw.ignore_tunnels:
            tunnel_up.labels(tunnel, roles[tunnel]).set(int(tunnel in active))
        # active but not found in config (Panorama templates, etc.) — show as up
        for tunnel in active - configured - disabled - self.fw.ignore_tunnels:
            tunnel_up.labels(tunnel, self.fw.tunnel_role(tunnel)).set(1)
        self._gauge(
            "panos_ipsec_tunnels_configured", "IPsec tunnels in config (excluding disabled)"
        ).set(len(configured))
        self._gauge(
            "panos_ipsec_tunnels_disabled", "Disabled IPsec tunnels in config"
        ).set(len(disabled))
        self._gauge("panos_ipsec_active_sa_count", "Number of active IPsec SAs").set(len(active))

    def collect_licenses(self):
        root = self.fw.op("<request><license><info/></license></request>")
        expiry = self._gauge(
            "panos_license_expiry_timestamp_seconds",
            "Unix time of license expiry (perpetual licenses are not exported)",
            ["feature"],
        )
        expired = self._gauge("panos_license_expired", "License has expired", ["feature"])
        for entry in root.findall(".//licenses/entry"):
            feature = entry.findtext("feature") or "unknown"
            expired.labels(feature).set(int((entry.findtext("expired") or "") == "yes"))
            expires = (entry.findtext("expires") or "").strip()
            if expires.lower() in ("", "never"):
                continue
            dt = parse_date(expires, LICENSE_DATE_FORMATS)
            if dt:
                expiry.labels(feature).set(dt.timestamp())
            else:
                log.warning("[%s] failed to parse license date %r (%s)",
                            self.fw.name, expires, feature)

    def collect_certificates(self):
        expiry = self._gauge(
            "panos_certificate_expiry_timestamp_seconds",
            "Unix time of certificate expiry in the PAN-OS store",
            ["certificate"],
        )
        for xpath in CERT_XPATHS:
            try:
                root = self.fw.config_get(xpath)
            except Exception:
                # On some configs (e.g. no vsys) the xpath is absent — fine.
                log.debug("[%s] xpath %s could not be read", self.fw.name, xpath)
                continue
            for entry in root.findall(".//certificate/entry"):
                name = entry.get("name") or "unknown"
                epoch = entry.findtext("expiry-epoch")
                if epoch and epoch.strip().isdigit():
                    expiry.labels(name).set(float(epoch.strip()))
                    continue
                dt = parse_date(entry.findtext("not-valid-after"), CERT_DATE_FORMATS)
                if dt:
                    expiry.labels(name).set(dt.timestamp())
                else:
                    log.warning("[%s] failed to parse certificate expiry %s", self.fw.name, name)

    def collect_sessions(self):
        root = self.fw.op("<show><session><info/></session></show>")
        active = root.findtext("./result/num-active")
        maximum = root.findtext("./result/num-max")
        if active is not None:
            self._gauge("panos_sessions_active", "Active sessions").set(float(active))
        if maximum is not None:
            self._gauge("panos_sessions_max", "Session table maximum").set(float(maximum))


class Handler(BaseHTTPRequestHandler):
    firewalls = {}

    def log_message(self, fmt, *args):  # noisy default log — to debug
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
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/-/healthy":
            return self._respond(200, "ok\n")
        if parsed.path != "/metrics":
            return self._respond(404, "use /metrics?target=<firewall-name>\n")
        target = (urllib.parse.parse_qs(parsed.query).get("target") or [""])[0]
        if not target:
            return self._respond(400, "missing ?target=\n")
        fw = self.firewalls.get(target)
        if fw is None:
            return self._respond(
                404, f"unknown target {target!r}; known: {sorted(self.firewalls)}\n"
            )
        try:
            body = Collector(fw).collect()
        except Exception:
            log.exception("scrape %s failed", target)
            return self._respond(500, "internal error, see logs\n")
        self._respond(200, body, CONTENT_TYPE_LATEST)


def main():
    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
    )
    with open(CONFIG_PATH) as f:
        cfg = yaml.safe_load(f) or {}
    firewalls = {
        name: Firewall(name, fw_cfg) for name, fw_cfg in (cfg.get("firewalls") or {}).items()
    }
    if not firewalls:
        log.error("config %s has no firewalls", CONFIG_PATH)
        sys.exit(1)
    Handler.firewalls = firewalls
    host, _, port = (cfg.get("listen") or "0.0.0.0:9654").rpartition(":")
    server = ThreadingHTTPServer((host, int(port)), Handler)
    log.info("listening on %s:%s, firewalls in config: %d", host, port, len(firewalls))
    server.serve_forever()


if __name__ == "__main__":
    main()
