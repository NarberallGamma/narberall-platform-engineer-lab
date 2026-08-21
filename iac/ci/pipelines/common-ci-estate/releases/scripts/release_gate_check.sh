#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release_lib.sh
source "${SCRIPT_DIR}/release_lib.sh"

release_log_header "release_gate_check"
mode="${1:-preflight}"

release_require_current_branch
release_require_token

echo "mode=${mode}"
echo "group=${RELEASE_GROUP_PATH:-estate}"
echo "OK: RELEASE_CURRENT_BRANCH and RELEASE_BOT_TOKEN present"

if [[ "$mode" == "preflight" ]]; then
  release_print_release_state "$RELEASE_CURRENT_BRANCH"
fi

echo "=== preflight OK ==="
