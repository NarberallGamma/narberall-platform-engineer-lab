"""Корень репозитория в sys.path: скрипты лежат плоско, пакета нет."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
