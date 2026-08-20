#!/usr/bin/env bash
# Общая подготовка SSH для MCP run_script и диагностических скриптов.
# Использование: source .../mcp_ssh_env.sh [host_alias]
#
# Выставляет: SSH_AUTH_SOCK (лучший agent с ключами), SSH_OPTS (массив),
# SSH_IDENTITY_FILE, SSH_TARGET_USER, SSH_TARGET_HOST.

_mcp_ssh_pick_agent_sock() {
  local sock key_count
  for sock in "${SSH_AUTH_SOCK:+$SSH_AUTH_SOCK}" /tmp/ssh-*/agent.*; do
    [[ -n "$sock" && -S "$sock" && -r "$sock" ]] || continue
    key_count="$(SSH_AUTH_SOCK="$sock" ssh-add -l 2>/dev/null | grep -c 'SHA256:' || true)"
    if [[ "$key_count" -gt 0 ]]; then
      export SSH_AUTH_SOCK="$sock"
      return 0
    fi
  done
  for sock in /tmp/ssh-*/agent.*; do
    [[ -S "$sock" && -r "$sock" ]] || continue
    export SSH_AUTH_SOCK="$sock"
    return 0
  done
  return 1
}

mcp_ssh_prepare() {
  local host_alias="${1:-}"
  local identity user host

  _mcp_ssh_pick_agent_sock || true

  if [[ -n "$host_alias" ]]; then
    identity="$(ssh -G "$host_alias" 2>/dev/null | awk '$1=="identityfile"{f=$2} END{print f}')"
    user="$(ssh -G "$host_alias" 2>/dev/null | awk '$1=="user"{u=$2} END{print u}')"
    host="$(ssh -G "$host_alias" 2>/dev/null | awk '$1=="hostname"{h=$2} END{print h}')"
  fi

  if [[ -z "${identity:-}" || "$identity" == "none" || ! -f "$identity" ]]; then
    identity="${HOME}/.ssh/id_ed25519"
  fi

  export SSH_IDENTITY_FILE="$identity"
  export SSH_TARGET_USER="${user:-}"
  export SSH_TARGET_HOST="${host:-}"

  SSH_OPTS=(
    -o BatchMode=yes
    -o ConnectTimeout=25
    -o IdentitiesOnly=yes
    -o StrictHostKeyChecking=accept-new
    -i "$SSH_IDENTITY_FILE"
  )
  export SSH_OPTS
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  mcp_ssh_prepare "${1:-}"
  echo "SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-unset}"
  echo "SSH_IDENTITY_FILE=${SSH_IDENTITY_FILE:-unset}"
  echo "SSH_TARGET_USER=${SSH_TARGET_USER:-}"
  echo "SSH_TARGET_HOST=${SSH_TARGET_HOST:-}"
  SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-}" ssh-add -l 2>/dev/null || true
fi
