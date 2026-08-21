"""
Настройка логирования (stdout, уровень из конфига).
"""

from __future__ import annotations

import logging
import sys
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from config import OrchestratorConfig

_logger: logging.Logger | None = None


def setup_logging(cfg: "OrchestratorConfig") -> None:
    global _logger
    level = getattr(logging, cfg.logging.level.upper(), logging.INFO)
    root = logging.getLogger()
    root.handlers.clear()
    root.setLevel(level)
    h = logging.StreamHandler(sys.stdout)
    h.setLevel(level)
    if cfg.logging.format == "json":
        fmt = logging.Formatter('{"level":"%(levelname)s","msg":"%(message)s"}')
    else:
        fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
    h.setFormatter(fmt)
    root.addHandler(h)
    _logger = logging.getLogger("cert-orchestrator")
    _logger.setLevel(level)


def get_logger() -> logging.Logger:
    global _logger
    if _logger is None:
        _logger = logging.getLogger("cert-orchestrator")
    return _logger
