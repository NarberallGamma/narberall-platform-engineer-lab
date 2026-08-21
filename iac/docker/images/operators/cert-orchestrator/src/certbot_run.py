"""certbot certonly + плагин REG.RU DNS (entry point «dns», флаги --dns-* в Certbot 3.x). Вызов через бинарник certbot из PATH (python -m certbot в части сборок недоступен)."""

from __future__ import annotations

import os
import shutil
import subprocess
from typing import List

from config import OrchestratorConfig
from regru_ini import RegruCredentialsError, resolve_regru_credentials_path


def build_certbot_cmd(cfg: OrchestratorConfig, force_renewal: bool = False) -> List[str]:
    le = cfg.letsencrypt
    if not (le.email or "").strip():
        raise ValueError("letsencrypt.email обязателен для certbot")
    if not (le.domain or "").strip():
        raise ValueError("letsencrypt.domain обязателен")
    creds = resolve_regru_credentials_path(le)
    domain = le.domain.strip()
    certbot_bin = shutil.which("certbot") or "certbot"
    cmd: List[str] = [
        certbot_bin,
        "certonly",
        "-a",
        "dns",
        "--dns-credentials",
        str(creds),
        "--dns-propagation-seconds",
        str(le.dns_propagation_seconds),
        "--email",
        le.email.strip(),
        "--agree-tos",
        "--no-eff-email",
        "--non-interactive",
        "-d",
        f"*.{domain}",
        "-d",
        domain,
    ]
    if force_renewal:
        cmd.append("--force-renewal")
    for x in le.certbot_extra_args:
        if x:
            cmd.append(str(x))
    return cmd


def run_certbot(cfg: OrchestratorConfig, force_renewal: bool = False) -> int:
    try:
        cmd = build_certbot_cmd(cfg, force_renewal=force_renewal)
    except (RegruCredentialsError, ValueError) as e:
        raise RuntimeError(str(e)) from e
    env = os.environ.copy()
    timeout = max(60, cfg.timeouts.certbot_seconds)
    r = subprocess.run(cmd, env=env, timeout=timeout)
    return int(r.returncode)
