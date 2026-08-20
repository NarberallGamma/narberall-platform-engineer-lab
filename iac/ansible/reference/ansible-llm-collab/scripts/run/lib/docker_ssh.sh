#!/usr/bin/env bash
# Общая логика SSH для scripts/run/*.sh (source после set -euo pipefail).
#
# === Ключ с passphrase (WSL / локальный запуск) ===
# Ansible в Docker неинтерактивен — зашифрованный ключ без ssh-agent не сработает.
#
#   eval "$(ssh-agent -s)"
#   ssh-add ~/.ssh/your_key              # passphrase один раз на сессию WSL
#   ssh-add -l                           # убедиться, что ключ в agent
#
#   ./scripts/run/run_*.sh ... \
#     --ssh-key ~/.ssh/your_key \
#     --ssh-agent
#
# --ssh-key  — монтирует ключ в /work/.ssh_key_mount (нужно при IdentitiesOnly=yes в inventory).
# --ssh-agent — пробрасывает SSH_AUTH_SOCK в контейнер (расшифровка passphrase).
# Только --ssh-agent (без --ssh-key) — сбрасывает ключ и IdentitiesOnly из inventory, ключи берутся из agent.
#
# Вход (globals): SSH_KEY_PATH, USE_SSH_AGENT, ASK_PASS
# Выход: дополняет DOCKER_MOUNTS[], DOCKER_ENV[], ANSIBLE_EXTRA[]

docker_ssh_apply() {
  if [[ -n "${ASK_PASS:-}" ]]; then
    if [[ -n "${SSH_KEY_PATH:-}" || -n "${USE_SSH_AGENT:-}" ]]; then
      echo "ERROR: --ask-pass несовместим с --ssh-key / --ssh-agent" >&2
      return 1
    fi
    ANSIBLE_EXTRA+=(-e ansible_ssh_private_key_file= -k)
    return 0
  fi

  if [[ -n "${USE_SSH_AGENT:-}" ]]; then
    if [[ -z "${SSH_AUTH_SOCK:-}" || ! -S "$SSH_AUTH_SOCK" ]]; then
      echo "ERROR: --ssh-agent требует ssh-agent (eval \"\$(ssh-agent -s)\" && ssh-add PATH_TO_KEY)" >&2
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
