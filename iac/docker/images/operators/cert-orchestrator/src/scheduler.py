"""Окно запуска renewal по конфигу и state."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from config import OrchestratorConfig
from state import load_state


def _parse_hhmm(s: str) -> tuple[int, int]:
    parts = (s or "03:30").strip().split(":")
    h = int(parts[0]) if parts else 3
    m = int(parts[1]) if len(parts) > 1 else 0
    return h % 24, m % 60


def _parse_iso_dt(iso: str) -> datetime | None:
    try:
        dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception:
        return None


def should_run_renewal(cfg: OrchestratorConfig, now: datetime | None = None) -> bool:
    tzname = (cfg.meta.timezone or "UTC").strip() or "UTC"
    try:
        tz = ZoneInfo(tzname)
    except Exception:
        tz = ZoneInfo("UTC")
    now = now or datetime.now(tz)
    if now.tzinfo is None:
        now = now.replace(tzinfo=tz)
    else:
        now = now.astimezone(tz)

    if now.weekday() != cfg.schedule.weekday_as_index():
        return False

    h, m = _parse_hhmm(cfg.schedule.time_hhmm)
    start = now.replace(hour=h, minute=m, second=0, microsecond=0)
    poll = max(60, int(cfg.schedule.poll_interval_seconds))
    end = start + timedelta(seconds=poll)
    if not (start <= now < end):
        return False

    min_days = int(cfg.schedule.days_interval)
    state = load_state()
    last_attempt_iso = state.get("last_run_attempt_iso")
    if isinstance(last_attempt_iso, str) and last_attempt_iso.strip():
        la = _parse_iso_dt(last_attempt_iso.strip())
        if la is not None:
            la = la.astimezone(tz)
            if la.date() == now.date() and start <= la < end:
                return False
            days = (now.date() - la.date()).days
            if days < min_days:
                return False

    return True
