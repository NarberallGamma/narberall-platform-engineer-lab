"""INI для certbot-regru (Certbot 3.x, plugin name dns): учётка только из env (.env)."""

from __future__ import annotations

from pathlib import Path

from config import LetsEncryptConfig

RUNTIME_DIR = Path("/run/cert-orchestrator")
RUNTIME_REGRU_INI = RUNTIME_DIR / "regru.ini"


class RegruCredentialsError(RuntimeError):
    """REG.RU credentials не заданы в env контейнера."""


def resolve_regru_credentials_path(cfg: LetsEncryptConfig) -> Path:
    u = (cfg.regru.dns_username or "").strip()
    p = (cfg.regru.dns_password or "").strip()
    if not u or not p:
        raise RegruCredentialsError(
            "REG.RU: задать REG_RU_DNS_USERNAME и REG_RU_DNS_PASSWORD в env контейнера "
            "(файл /docker/apps/cert-orchestrator/.env, ключи из Vault)"
        )

    RUNTIME_DIR.mkdir(parents=True, mode=0o700, exist_ok=True)
    # Certbot 3.x + entry point dns: плоские ключи dns_username / dns_password (не certbot_regru:...)
    content = f"dns_username = {u}\n" f"dns_password = {p}\n"
    RUNTIME_REGRU_INI.write_text(content, encoding="utf-8")
    RUNTIME_REGRU_INI.chmod(0o600)
    return RUNTIME_REGRU_INI
