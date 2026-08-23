"""INI for certbot-regru (Certbot 3.x, plugin name dns): credentials from env (.env) only."""

from __future__ import annotations

from pathlib import Path

from config import LetsEncryptConfig

RUNTIME_DIR = Path("/run/cert-orchestrator")
RUNTIME_REGRU_INI = RUNTIME_DIR / "regru.ini"


class RegruCredentialsError(RuntimeError):
    """REG.RU credentials are not set in the container env."""


def resolve_regru_credentials_path(cfg: LetsEncryptConfig) -> Path:
    u = (cfg.regru.dns_username or "").strip()
    p = (cfg.regru.dns_password or "").strip()
    if not u or not p:
        raise RegruCredentialsError(
            "REG.RU: set REG_RU_DNS_USERNAME and REG_RU_DNS_PASSWORD in the container env "
            "(file /docker/apps/cert-orchestrator/.env, keys from Vault)"
        )

    RUNTIME_DIR.mkdir(parents=True, mode=0o700, exist_ok=True)
    # Certbot 3.x + entry point dns: flat keys dns_username / dns_password (not certbot_regru:...)
    content = f"dns_username = {u}\n" f"dns_password = {p}\n"
    RUNTIME_REGRU_INI.write_text(content, encoding="utf-8")
    RUNTIME_REGRU_INI.chmod(0o600)
    return RUNTIME_REGRU_INI
