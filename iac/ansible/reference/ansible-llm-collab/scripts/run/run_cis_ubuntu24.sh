#!/usr/bin/env bash
# CIS Ubuntu 24 hardening (playbooks/cis_ubuntu24.yml, group_vars/cis_ubuntu24.yml).
#
# SSH-ключ с passphrase (WSL): eval "$(ssh-agent -s)" && ssh-add ~/.ssh/your_key
#   ./scripts/run/run_cis_ubuntu24.sh --remote --limit HOST --ssh-key ~/.ssh/your_key --ssh-agent
# Подробнее: scripts/run/lib/docker_ssh.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=lib/docker_ssh.sh
source "$(dirname "$0")/lib/docker_ssh.sh"

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-git.example.com/platform-infra/base-images/ansible:1.0}"

INV="inventories/hosts.ini"
SSH_KEY_PATH=""
ASK_PASS=""
USE_SSH_AGENT=""
EXTRA=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --local|-l)      INV="inventories/localhost/hosts.ini"; shift ;;
    --remote|-r)     INV="inventories/hosts.ini"; shift ;;
    --ssh-key|-k)    SSH_KEY_PATH="$2"; shift 2 ;;
    --ssh-agent)     USE_SSH_AGENT=1; shift ;;
    --ask-pass)      ASK_PASS=1; shift ;;
    --help|-h)
      cat <<'EOF'
Использование: run_cis_ubuntu24.sh [опции] [-- extra ansible-playbook args]

  --local, -l     inventories/localhost/hosts.ini
  --remote, -r    inventories/hosts.ini (по умолчанию)
  --limit HOST    ограничить хост из группы prepare
  --ssh-key PATH  монтировать ключ в контейнер
  --ssh-agent     проброс SSH agent (ключ с passphrase)
  --ask-pass      пароль SSH через Ansible

Переменные CIS: group_vars/cis_ubuntu24.yml
EOF
      exit 0
      ;;
    *)               EXTRA+=("$1"); shift ;;
  esac
done

if [[ "${EXTRA[0]:-}" == "--" ]]; then
  EXTRA=("${EXTRA[@]:1}")
fi

DOCKER_MOUNTS=()
DOCKER_ENV=(-e ANSIBLE_CONFIG=/work/ansible.cfg -e ANSIBLE_ROLES_PATH=/work/roles)
ANSIBLE_EXTRA=()
docker_ssh_apply

docker run --rm -it \
  -v "$(pwd):/work" -w /work \
  "${DOCKER_MOUNTS[@]}" \
  "${DOCKER_ENV[@]}" \
  --network host \
  "$ANSIBLE_IMAGE" \
  ansible-playbook -i "/work/$INV" "${ANSIBLE_EXTRA[@]}" "${EXTRA[@]}" playbooks/cis_ubuntu24.yml
