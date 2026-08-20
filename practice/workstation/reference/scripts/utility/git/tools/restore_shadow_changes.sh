#!/usr/bin/env bash
# Drop phantom (CRLF/EOL) and any uncommitted local changes — restore to HEAD.
# Usage:
#   restore_shadow_changes.sh --path /path/to/repo
#   restore_shadow_changes.sh --env PROD --repo cluster-resources --repo kafka-operator

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIAG="$SCRIPT_DIR/diagnose_shadow_diff.sh"
# shellcheck source=../../lib/infra_paths.sh
source "$SCRIPT_DIR/../../lib/infra_paths.sh"
load_infra_paths "$SCRIPT_DIR"
CR_ROOT="$GIT_ENV_ROOT"

ENV=""
REPOS=()
PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    --repo) REPOS+=("$2"); shift 2 ;;
    --path) PATHS+=("$2"); shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ${#PATHS[@]} -eq 0 && ${#REPOS[@]} -gt 0 && -n "$ENV" ]]; then
  for r in "${REPOS[@]}"; do
    PATHS+=("$CR_ROOT/$ENV/$r")
  done
fi

if [[ ${#PATHS[@]} -eq 0 ]]; then
  echo "Usage: $0 --path DIR | --env PREPROD|PROD --repo NAME [--repo ...]"
  exit 1
fi

for p in "${PATHS[@]}"; do
  echo ""
  bash "$DIAG" "$p" || true
  echo "[restore] resetting $(basename "$p") to HEAD"
  git -C "$p" restore --staged . 2>/dev/null || true
  git -C "$p" restore .
  git -C "$p" status -sb
done
