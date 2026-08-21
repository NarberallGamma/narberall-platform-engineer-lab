"""Проверка HTTPS: stdlib ssl (TCP + TLS, notAfter)."""

from __future__ import annotations

import hashlib
import ipaddress
import socket
import ssl
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import List

from config import HttpsVerificationConfig, OrchestratorConfig


def _fingerprint_sha256_colon(der: bytes) -> str:
    h = hashlib.sha256(der).hexdigest().upper()
    return ":".join(h[i : i + 2] for i in range(0, len(h), 2))


@dataclass
class HttpsCheckResult:
    ok: bool
    host: str
    port: int
    message: str
    not_after: datetime | None = None
    fingerprint_sha256: str | None = None


def _is_ip(s: str) -> bool:
    try:
        ipaddress.ip_address(s.split("%")[0])
        return True
    except ValueError:
        return False


def check_one(
    host: str,
    port: int,
    *,
    sni: str,
    timeout: float,
) -> HttpsCheckResult:
    host = host.strip()
    if not host:
        return HttpsCheckResult(False, host, port, "пустой host")

    server_name = (sni or host).strip() or host
    ctx = ssl.create_default_context()

    try:
        with socket.create_connection((host, port), timeout=timeout) as sock:
            with ctx.wrap_socket(sock, server_hostname=server_name) as ssock:
                cert_der = ssock.getpeercert(binary_form=True)
                fp = _fingerprint_sha256_colon(cert_der) if cert_der else None
                cert = ssock.getpeercert()
                if not cert:
                    return HttpsCheckResult(False, host, port, "нет сертификата с peer", None, fp)
                na = cert.get("notAfter")
                if not na:
                    return HttpsCheckResult(False, host, port, "нет notAfter в сертификате", None, fp)
                not_after = datetime.fromtimestamp(ssl.cert_time_to_seconds(na), tz=timezone.utc)
                now = datetime.now(timezone.utc)
                if not_after < now:
                    return HttpsCheckResult(
                        False,
                        host,
                        port,
                        f"сертификат просрочен (notAfter={na})",
                        not_after,
                        fp,
                    )
                return HttpsCheckResult(
                    True,
                    host,
                    port,
                    f"OK, истекает {na}",
                    not_after,
                    fp,
                )
    except Exception as e:
        return HttpsCheckResult(False, host, port, str(e), None, None)


def run_all(cfg: OrchestratorConfig) -> List[HttpsCheckResult]:
    hv: HttpsVerificationConfig = cfg.https_verification
    if not hv.enabled:
        return []

    timeout = float(max(1, hv.ssl_timeout_seconds))
    out: List[HttpsCheckResult] = []
    for h in hv.hosts:
        if not h.enabled or not (h.host or "").strip():
            continue
        sni = (h.sni or "").strip()
        if not sni and _is_ip(h.host):
            out.append(
                HttpsCheckResult(
                    False,
                    h.host,
                    h.port,
                    "для подключения по IP задать sni (имя в сертификате/SNI)",
                    None,
                    None,
                )
            )
            continue
        out.append(
            check_one(
                h.host,
                h.port,
                sni=sni or h.host,
                timeout=timeout,
            )
        )
    return out


def results_to_log_lines(results: List[HttpsCheckResult]) -> List[str]:
    lines = []
    for r in results:
        status = "OK" if r.ok else "FAIL"
        extra = f" fp={r.fingerprint_sha256}" if r.fingerprint_sha256 else ""
        lines.append(f"[{status}] {r.host}:{r.port} — {r.message}{extra}")
    return lines
