"""fullchain.pem / privkey.pem."""

from __future__ import annotations

from pathlib import Path

from config import LetsEncryptConfig


def live_directory(cfg: LetsEncryptConfig) -> Path:
    d = (cfg.live_dir or "").strip()
    if d:
        return Path(d)
    dom = (cfg.domain or "").strip()
    if not dom:
        raise ValueError("letsencrypt.domain не задан")
    return Path("/etc/letsencrypt/live") / dom


def pem_paths(cfg: LetsEncryptConfig) -> tuple[Path, Path]:
    base = live_directory(cfg)
    return base / "fullchain.pem", base / "privkey.pem"
