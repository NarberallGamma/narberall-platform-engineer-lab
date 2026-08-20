#!/usr/bin/env bash
# Remote fragment: deploy pubkey + NOPASSWD sudo for admin (run via ssh bash -s).
# Args: $1=target_user $2=pubkey_line
set -euo pipefail
tu=$1
pk=$2

if [[ $(id -u) -eq 0 ]] && ! id "$tu" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$tu" 2>/dev/null || true
fi

setup_admin_nopasswd_sudo() {
  [[ $(id -u) -eq 0 ]] || return 0
  local f="/etc/sudoers.d/${tu}"
  local line="${tu} ALL=(ALL) NOPASSWD:ALL"
  printf '%s\n' "$line" >"$f"
  chmod 440 "$f"
  if command -v visudo >/dev/null 2>&1; then
    visudo -cf "$f"
  fi
  echo sudo_nopasswd=ok
}

home=$(getent passwd "$tu" | cut -d: -f6 || true)
[[ -n "$home" ]] || exit 1

if [[ $(id -u) -eq 0 ]]; then
  mkdir -p "$home/.ssh"
  chown "$tu:" "$home/.ssh" 2>/dev/null || chown "$tu" "$home/.ssh"
  chmod 700 "$home/.ssh"
  auth="$home/.ssh/authorized_keys"
  touch "$auth"
  grep -qF "$pk" "$auth" 2>/dev/null || echo "$pk" >>"$auth"
  chown "$tu:" "$auth" 2>/dev/null || chown "$tu" "$auth"
  chmod 600 "$auth"
else
  auth="$home/.ssh/authorized_keys"
  mkdir -p "$home/.ssh" && chmod 700 "$home/.ssh"
  touch "$auth"
  grep -qF "$pk" "$auth" 2>/dev/null || echo "$pk" >>"$auth"
  chmod 600 "$auth"
fi

setup_admin_nopasswd_sudo
echo deployed_user="$tu"
