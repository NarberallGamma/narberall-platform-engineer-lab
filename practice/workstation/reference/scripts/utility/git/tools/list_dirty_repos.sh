#!/usr/bin/env bash
# Список git-репозиториев с незакоммиченными изменениями.
# Usage: list_dirty_repos.sh --env PREPROD|PROD

set -euo pipefail

ENV=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --env PREPROD|PROD"
      exit 0
      ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$ENV" ]] || { echo "Specify --env PREPROD or PROD" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/infra_paths.sh
source "$SCRIPT_DIR/../../lib/infra_paths.sh"
load_infra_paths "$SCRIPT_DIR"
CR="$GIT_ENV_ROOT"
BASE="$CR/$ENV"
count=0

echo "Dirty repos in $BASE:"
echo ""

for g in "$BASE"/*/.git; do
  [[ -d "$g" ]] || continue
  d=$(dirname "$g")
  n=$(basename "$d")
  s=$(git -C "$d" status --porcelain 2>/dev/null || true)
  if [[ -n "$s" ]]; then
    ((count++)) || true
    echo "=== $n (branch: $(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)) ==="
    echo "$s" | head -5
    lines=$(echo "$s" | wc -l)
    [[ "$lines" -gt 5 ]] && echo "  ... +$((lines - 5)) more"
    echo ""
  fi
done

echo "Total dirty: $count"
