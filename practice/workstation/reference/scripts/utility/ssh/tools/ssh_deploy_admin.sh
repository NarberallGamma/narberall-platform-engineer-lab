#!/usr/bin/env bash
# Deploy admin pubkey + NOPASSWD sudo via current config User (sudo or root).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/../lib/remote_deploy_admin_key.sh"
# shellcheck source=../lib/ssh_agent_env.sh
source "$SCRIPT_DIR/../lib/ssh_agent_env.sh"

ssh_agent_env || true
ssh_util_base_opts

TARGET_USER="${TARGET_USER:-admin}"
PUBKEY_LINE=$(tr -d '\r\n' <"${SSH_UTIL_PUB:?}")
OUT="${OUT:-}"

usage() {
  echo "Usage: OUT=... $0 alias [alias ...]" >&2
  exit 1
}

[[ $# -gt 0 ]] || usage

log() {
  echo "$@"
  [[ -n "$OUT" ]] && echo "$@" >>"$OUT"
}

run_remote() {
  local alias="$1"
  if ssh "${SSH_UTIL_OPTS[@]}" "$alias" "sudo bash -s -- ${TARGET_USER} $(printf '%q' "$PUBKEY_LINE")" <"$LIB"; then
    return 0
  fi
  ssh "${SSH_UTIL_OPTS[@]}" "$alias" "bash -s -- ${TARGET_USER} $(printf '%q' "$PUBKEY_LINE")" <"$LIB"
}

verify_admin() {
  local alias="$1" ip="$2"
  local hn
  hn=$(ssh "${SSH_UTIL_OPTS[@]}" -o "User=${TARGET_USER}" -o "Hostname=$ip" "$alias" 'hostname -s' </dev/null 2>/dev/null) || return 1
  log "OK ${TARGET_USER}@${ip} -> $hn"
  ssh "${SSH_UTIL_OPTS[@]}" -o "User=${TARGET_USER}" -o "Hostname=$ip" "$alias" 'sudo -n true' </dev/null 2>/dev/null \
    && log "OK sudo_nopasswd@${ip}" || log "WARN sudo@${ip} (or PAM/SSSD block)"
  return 0
}

[[ -n "$OUT" ]] && : >"$OUT"
log "=== ssh_deploy_admin $(date -Is) target=${TARGET_USER} ==="

ok=0 fail=0
for alias in "$@"; do
  ip=$(ssh -G "$alias" 2>/dev/null | awk '/^hostname / {print $2; exit}')
  user=$(ssh -G "$alias" 2>/dev/null | awk '/^user / {print $2; exit}')
  ip="${ip//$'\r'/}"; user="${user//$'\r'/}"
  log "--- $alias (config user=$user ip=$ip) ---"
  if ! ssh "${SSH_UTIL_OPTS[@]}" "$alias" 'true' </dev/null 2>/dev/null; then
    log "FAIL login $alias as $user"
    fail=$((fail + 1))
    continue
  fi
  if ! run_remote "$alias"; then
    log "FAIL deploy on $alias"
    fail=$((fail + 1))
    continue
  fi
  if verify_admin "$alias" "$ip"; then
    ok=$((ok + 1))
  else
    log "FAIL verify ${TARGET_USER} on $alias (check pam_sss / set-user in config)"
    fail=$((fail + 1))
  fi
done

log "=== done ok=$ok fail=$fail ==="
exit $([[ "$fail" -eq 0 ]] && echo 0 || echo 1)
