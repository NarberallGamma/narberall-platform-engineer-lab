#!/usr/bin/env bash
# Source from other ssh utility scripts: export SSH_AUTH_SOCK if agent has keys.
ssh_agent_env() {
  if [[ -n "${SSH_AUTH_SOCK:-}" ]] && ssh-add -l >/dev/null 2>&1; then
    return 0
  fi
  local sock
  for sock in /tmp/ssh-*/agent.*; do
    [[ -S "$sock" ]] || continue
    export SSH_AUTH_SOCK="$sock"
    ssh-add -l >/dev/null 2>&1 && return 0
  done
  return 1
}

SSH_UTIL_KEY="${SSH_UTIL_KEY:-$HOME/.ssh/id_ed25519}"
SSH_UTIL_PUB="${SSH_UTIL_PUB:-$HOME/.ssh/id_ed25519.pub}"

ssh_util_base_opts() {
  SSH_UTIL_OPTS=(-o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -i "$SSH_UTIL_KEY")
}
