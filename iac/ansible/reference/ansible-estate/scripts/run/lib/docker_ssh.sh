#!/usr/bin/env bash
# Shared SSH logic for scripts/run/*.sh (source after set -euo pipefail).
#
# === Key with passphrase (local run) ===
# Ansible in Docker is non-interactive — an encrypted key without ssh-agent will not work.
#
#   eval "$(ssh-agent -s)"
#   ssh-add ~/.ssh/your_key              # passphrase once per session
#   ssh-add -l                           # confirm the key is in the agent
#
#   ./scripts/run/run_*.sh ... \
#     --ssh-key ~/.ssh/your_key \
#     --ssh-agent
#
# --ssh-key  — mounts the key at /work/.ssh_key_mount (needed when IdentitiesOnly=yes in inventory).
# --ssh-agent — forwards SSH_AUTH_SOCK into the container (passphrase unlock).
# --ssh-agent only (no --ssh-key) — clears the key and IdentitiesOnly from inventory; keys come from the agent.
#
# Input (globals): SSH_KEY_PATH, USE_SSH_AGENT, ASK_PASS
# Output: appends DOCKER_MOUNTS[], DOCKER_ENV[], ANSIBLE_EXTRA[]

docker_ssh_apply() {
  if [[ -n "${ASK_PASS:-}" ]]; then
    if [[ -n "${SSH_KEY_PATH:-}" || -n "${USE_SSH_AGENT:-}" ]]; then
      echo "ERROR: --ask-pass is incompatible with --ssh-key / --ssh-agent" >&2
      return 1
    fi
    ANSIBLE_EXTRA+=(-e ansible_ssh_private_key_file= -k)
    return 0
  fi

  if [[ -n "${USE_SSH_AGENT:-}" ]]; then
    if [[ -z "${SSH_AUTH_SOCK:-}" || ! -S "$SSH_AUTH_SOCK" ]]; then
      echo "ERROR: --ssh-agent requires ssh-agent (eval \"\$(ssh-agent -s)\" && ssh-add PATH_TO_KEY)" >&2
      return 1
    fi
    DOCKER_MOUNTS+=(-v "$SSH_AUTH_SOCK:/ssh-agent")
    DOCKER_ENV+=(-e SSH_AUTH_SOCK=/ssh-agent)
    if [[ -z "${SSH_KEY_PATH:-}" ]]; then
      ANSIBLE_EXTRA+=(-e ansible_ssh_private_key_file= -e ansible_private_key_file= -e ansible_ssh_common_args='')
    fi
  fi

  if [[ -n "${SSH_KEY_PATH:-}" ]]; then
    local resolved="${SSH_KEY_PATH/#\~/$HOME}"
    if [[ "$resolved" != /* ]]; then
      resolved="$(cd "$(dirname "$resolved")" && pwd)/$(basename "$resolved")"
    fi
    if [[ ! -f "$resolved" ]]; then
      echo "ERROR: SSH key not found: $resolved" >&2
      return 1
    fi
    DOCKER_MOUNTS+=(-v "$resolved:/work/.ssh_key_mount:ro")
    ANSIBLE_EXTRA+=(-e ansible_ssh_private_key_file=/work/.ssh_key_mount -e ansible_private_key_file=/work/.ssh_key_mount)
  fi
}
