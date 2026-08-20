#!/usr/bin/env bash
# Kafka deploy. SSH-ключ с passphrase: eval "$(ssh-agent -s)" && ssh-add ~/.ssh/your_key
#   ./scripts/run/run_kafka.sh --limit kafka-prod.example.com --ssh-key ~/.ssh/your_key --ssh-agent
# Подробнее: scripts/run/lib/docker_ssh.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=lib/docker_ssh.sh
source "$(dirname "$0")/lib/docker_ssh.sh"
# Подхват Vault-переменных с контрол-ноды (создаются пайплайном из CI Variables в /ansible/.env.vault).
[ -f .env.vault ] && source .env.vault

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-git.example.com/platform-infra/base-images/ansible:1.0}"

INV="inventories/hosts.ini"
PLAYBOOK="playbooks/kafka_deploy.yml"
LIMIT_HOST=""
SSH_KEY_PATH=""
ASK_PASS=""
USE_SSH_AGENT=""
EXTRA=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --playbook|-p)   PLAYBOOK="$2"; shift 2 ;;
    --limit|-L)      LIMIT_HOST="$2"; shift 2 ;;
    --local|-l)      INV="inventories/localhost/hosts.ini"; shift ;;
    --remote|-r)     INV="inventories/hosts.ini"; shift ;;
    --ssh-key|-k)    SSH_KEY_PATH="$2"; shift 2 ;;
    --ssh-agent)     USE_SSH_AGENT=1; shift ;;
    --ask-pass)      ASK_PASS=1; shift ;;
    *)               EXTRA+=("$1"); shift ;;
  esac
done

if [[ -z "${LIMIT_HOST:-}" ]]; then
  echo "Ошибка: задайте хост, например: --limit kafka-prod.example.com" >&2
  exit 1
fi

DOCKER_MOUNTS=()
DOCKER_ENV=(-e ANSIBLE_CONFIG=/work/ansible.cfg -e ANSIBLE_ROLES_PATH=/work/roles)
ANSIBLE_EXTRA=()
docker_ssh_apply
if [[ -z "$SSH_KEY_PATH" && -z "$USE_SSH_AGENT" && -z "$ASK_PASS" && -f .ssh/ansible_ssh_key ]]; then
  DOCKER_MOUNTS+=(-v "$(pwd)/.ssh:/work/.ssh:ro")
  ANSIBLE_EXTRA+=(-e ansible_ssh_private_key_file=/work/.ssh/ansible_ssh_key)
fi

VAULT_ENV=()
[[ -n "${VAULT_ADDR:-}" ]] && VAULT_ENV+=(-e "VAULT_ADDR=$VAULT_ADDR")
[[ -n "${VAULT_TOKEN:-}" ]] && VAULT_ENV+=(-e "VAULT_TOKEN=$VAULT_TOKEN")

LOG_DIR="artifacts/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/kafka_deploy_$(date +%Y-%m-%d_%H-%M-%S).log"
echo "Лог вывода: $LOG_FILE" >&2

DOCKER_TTY=""
[[ -t 0 ]] && [[ -t 1 ]] && DOCKER_TTY="-it"

docker run --rm $DOCKER_TTY \
  -v "$(pwd):/work" -w /work \
  "${DOCKER_MOUNTS[@]}" \
  "${VAULT_ENV[@]}" \
  "${DOCKER_ENV[@]}" \
  --network host \
  "$ANSIBLE_IMAGE" \
  ansible-playbook -i "/work/$INV" "/work/$PLAYBOOK" --limit "$LIMIT_HOST" "${ANSIBLE_EXTRA[@]}" "${EXTRA[@]}" 2>&1 | tee "$LOG_FILE"
