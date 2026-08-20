#!/usr/bin/env bash
# Open issues assigned to current user (all projects or INFRA-only).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INFRA_ONLY=false
MAX=100

while [[ $# -gt 0 ]]; do
  case "$1" in
    --infra-only) INFRA_ONLY=true; shift ;;
    --max) MAX="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: sd_my_open.sh [--infra-only] [--max N]"
      exit 0
      ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

jql="assignee = currentUser() AND resolution = Unresolved"
if [[ "$INFRA_ONLY" == true ]]; then
  jql="project = INFRA AND ${jql}"
fi

exec "$SCRIPT_DIR/sd_search.sh" --jql-full "$jql" --max "$MAX"
