"""День недели: monday…sunday, сокращения или 0–6 (понедельник–воскресенье)."""

from __future__ import annotations

from typing import Any

WEEKDAY_ALIASES_TO_INDEX: dict[str, int] = {
    "monday": 0,
    "mon": 0,
    "tuesday": 1,
    "tue": 1,
    "tues": 1,
    "wednesday": 2,
    "wed": 2,
    "wendsday": 2,
    "thursday": 3,
    "thu": 3,
    "thurs": 3,
    "friday": 4,
    "fri": 4,
    "saturday": 5,
    "sat": 5,
    "sunday": 6,
    "sun": 6,
}

_INDEX_TO_CANONICAL = (
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday",
)


def parse_weekday_value(raw: Any) -> str:
    """Каноническое имя monday…sunday. Пустое — вторник."""
    idx = parse_weekday_to_index(raw)
    return _INDEX_TO_CANONICAL[idx]


def parse_weekday_to_index(raw: Any) -> int:
    """0 = понедельник … 6 = воскресенье."""
    if raw is None or raw == "":
        return 1
    if isinstance(raw, int):
        if 0 <= raw <= 6:
            return raw
        raise ValueError(f"schedule.weekday: ожидается 0–6 или имя дня, получено {raw!r}")
    s = str(raw).strip().lower()
    if s.isdigit():
        return parse_weekday_to_index(int(s))
    if s in WEEKDAY_ALIASES_TO_INDEX:
        return WEEKDAY_ALIASES_TO_INDEX[s]
    raise ValueError(
        f"schedule.weekday: неизвестный день {raw!r}; ожидаются monday, tuesday, … или 0–6"
    )


def weekday_index(canonical_name: str) -> int:
    n = canonical_name.strip().lower()
    if n not in WEEKDAY_ALIASES_TO_INDEX:
        raise ValueError(f"внутренняя ошибка: {canonical_name!r}")
    return WEEKDAY_ALIASES_TO_INDEX[n]
