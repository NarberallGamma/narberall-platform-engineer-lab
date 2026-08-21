"""Результат раскладки cert на один target (K8s namespace, nginx host, …)."""

from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any, List


@dataclass
class TargetDeployResult:
    kind: str
    target_id: str
    ok: bool
    detail: str = ""

    def to_state_dict(self) -> dict[str, Any]:
        return asdict(self)


def results_to_step_lines(results: List[TargetDeployResult]) -> List[tuple[str, bool, str]]:
    lines: List[tuple[str, bool, str]] = []
    for r in results:
        label = f"{r.kind} {r.target_id}".strip()
        lines.append((label, r.ok, r.detail))
    return lines


def all_ok(results: List[TargetDeployResult]) -> bool:
    return bool(results) and all(r.ok for r in results)


def any_ok(results: List[TargetDeployResult]) -> bool:
    return any(r.ok for r in results)


def summarize(results: List[TargetDeployResult]) -> tuple[int, int]:
    ok = sum(1 for r in results if r.ok)
    return ok, len(results)
