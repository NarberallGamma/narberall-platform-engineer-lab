"""state.json: CERT_ORCHESTRATOR_STATE_DIR или /var/lib/cert-orchestrator."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_STATE_DIR = "/var/lib/cert-orchestrator"


def state_dir() -> Path:
    return Path(os.environ.get("CERT_ORCHESTRATOR_STATE_DIR", DEFAULT_STATE_DIR))


def state_path() -> Path:
    return state_dir() / "state.json"


def load_state() -> dict[str, Any]:
    p = state_path()
    if not p.is_file():
        return {}
    try:
        with p.open("r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def save_state(data: dict[str, Any]) -> None:
    state_dir().mkdir(parents=True, exist_ok=True)
    p = state_path()
    tmp = p.with_suffix(".json.tmp")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, sort_keys=True)
    tmp.replace(p)


def record_renewal_attempt(
    *,
    success: bool,
    partial: bool = False,
    target_results: list[dict[str, Any]] | None = None,
) -> None:
    now = datetime.now(timezone.utc)
    iso = now.isoformat()
    s = load_state()
    s["last_run_attempt_iso"] = iso
    s["last_run_success"] = success
    s["last_run_partial"] = partial
    if success:
        s["last_success_iso"] = iso
    if target_results is not None:
        s["last_target_results"] = target_results
    save_state(s)
