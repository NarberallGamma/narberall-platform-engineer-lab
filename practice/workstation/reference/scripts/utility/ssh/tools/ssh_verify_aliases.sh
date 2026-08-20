#!/usr/bin/env bash
# Quick verify: ssh alias -> hostname -s (uses config User/IdentityFile).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/ssh_agent_env.sh
source "$SCRIPT_DIR/../lib/ssh_agent_env.sh"
ssh_agent_env || true
ssh_util_base_opts

[[ $# -gt 0 ]] || { echo "Usage: $0 alias [alias ...]" >&2; exit 1; }

echo "=== ssh_verify_aliases $(date -Is) ==="
fail=0
for alias in "$@"; do
  u=$(ssh -G "$alias" 2>/dev/null | awk '/^user / {print $2; exit}')
  u="${u//$'\r'/}"
  echo -n "$alias (user=$u): "
  if out=$(ssh "${SSH_UTIL_OPTS[@]}" "$alias" 'hostname -s' 2>&1); then
    echo "$out"
  else
    echo "$out" | head -1
    fail=$((fail + 1))
  fi
done
exit $([[ "$fail" -eq 0 ]] && echo 0 || echo 1)
