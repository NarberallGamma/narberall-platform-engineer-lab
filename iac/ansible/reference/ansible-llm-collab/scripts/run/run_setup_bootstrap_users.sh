#!/usr/bin/env bash
# Bootstrap пользователей ansible и gitlab-runner.
#
# SSH-ключ с passphrase (WSL): eval "$(ssh-agent -s)" && ssh-add ~/.ssh/your_key
#   ./scripts/run/run_setup_bootstrap_users.sh --remote --limit HOST --ssh-key ~/.ssh/your_key --ssh-agent
# -u/--user: первый SSH-пользователь (передаётся как -e ansible_user=…).
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
BOOTSTRAP_REMOTE_USER=""
EXTRA=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --local|-l)      INV="inventories/localhost/hosts.ini"; shift ;;
    --remote|-r)     INV="inventories/hosts.ini"; shift ;;
    --ssh-key|-k)    SSH_KEY_PATH="$2"; shift 2 ;;
    --ssh-agent)     USE_SSH_AGENT=1; shift ;;
    --ask-pass)      ASK_PASS=1; shift ;;
    -u|--user)       BOOTSTRAP_REMOTE_USER="$2"; shift 2 ;;
    *)               EXTRA+=("$1"); shift ;;
  esac
done

DOCKER_MOUNTS=()
DOCKER_ENV=(-e ANSIBLE_CONFIG=/work/ansible.cfg -e ANSIBLE_ROLES_PATH=/work/roles)
ANSIBLE_EXTRA=()
docker_ssh_apply

if [[ -z "$SSH_KEY_PATH" && -z "$USE_SSH_AGENT" && -z "$ASK_PASS" && -f .ssh/ansible_ssh_key ]]; then
  DOCKER_MOUNTS+=(-v "$(pwd)/.ssh:/work/.ssh:ro")
  ANSIBLE_EXTRA+=(-e ansible_ssh_private_key_file=/work/.ssh/ansible_ssh_key)
fi

BOOTSTRAP_CONN_OVERRIDE=()
if [[ -n "${BOOTSTRAP_REMOTE_USER:-}" ]]; then
  BOOTSTRAP_CONN_OVERRIDE+=(-e "ansible_user=${BOOTSTRAP_REMOTE_USER}")
fi

docker run --rm -it \
  -v "$(pwd):/work" -w /work \
  "${DOCKER_MOUNTS[@]}" \
  "${DOCKER_ENV[@]}" \
  --network host \
  "$ANSIBLE_IMAGE" \
  ansible-playbook -i "/work/$INV" "${ANSIBLE_EXTRA[@]}" "${EXTRA[@]}" "${BOOTSTRAP_CONN_OVERRIDE[@]}" playbooks/setup_bootstrap_users.yml
