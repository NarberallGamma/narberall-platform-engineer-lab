"""Repo root on sys.path: scripts sit at the top level, there is no package."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
