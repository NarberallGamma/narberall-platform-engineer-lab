#!/usr/bin/env bash
# Deploy local Telegram VPS egress Envoy on GitLab (docker network + proxy container).
#
#   ./scripts/run/run_telegram_vps_egress.sh --prod --limit estate-prod-gitlab
#   ./scripts/run/run_telegram_vps_egress.sh --preprod --limit estate-preprod-gitlab
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=lib/docker_ssh.sh
source "$(dirname "$0")/lib/docker_ssh.sh"
# shellcheck source=lib/control_node_env.sh
source "$(dirname "$0")/lib/control_node_env.sh"

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-registry.example.com/platform/base-images/ansible:1.0}"
INVENTORY=""
LIMIT_ARG=""
SCOPE_SPECIFIED=""
SSH_KEY_PATH=""
USE_SSH_AGENT=""
ASK_PASS=""
EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prod)    INVENTORY="inventories/prod/hosts.ini"; shift ;;
    --preprod) INVENTORY="inventories/preprod/hosts.ini"; shift ;;
    --all)     SCOPE_SPECIFIED=1; shift ;;
    --limit)   LIMIT_ARG="$2"; SCOPE_SPECIFIED=1; shift 2 ;;
    --ssh-key|-k) SSH_KEY_PATH="$2"; shift 2 ;;
    --ssh-agent)  USE_SSH_AGENT=1; shift ;;
    --ask-pass)   ASK_PASS=1; shift ;;
    *)         EXTRA+=("$1"); shift ;;
  esac
done

if [[ -z "$INVENTORY" ]]; then
  echo "ERROR: Specify --prod or --preprod"
  exit 1
fi
if [[ -z "$SCOPE_SPECIFIED" ]]; then
  echo "ERROR: Specify --all or --limit HOST"
  exit 1
fi
if [[ ! -f "$INVENTORY" ]]; then
  echo "ERROR: Inventory not found: $INVENTORY"
  exit 1
fi

DOCKER_MOUNTS=()
DOCKER_ENV=(-e ANSIBLE_CONFIG=/work/ansible.cfg -e ANSIBLE_ROLES_PATH=/work/roles)
ANSIBLE_EXTRA=()
docker_ssh_apply
control_node_env_apply

if [[ -f .ssh/ansible_ssh_key && -z "${SSH_KEY_PATH:-}" && -z "${USE_SSH_AGENT:-}" ]]; then
  ANSIBLE_EXTRA+=(-e ansible_user=ansible)
fi

LIMIT_OPT=()
[[ -n "$LIMIT_ARG" ]] && LIMIT_OPT=(--limit "$LIMIT_ARG")

docker run --rm -it \
  -v "$(pwd):/work" -w /work \
  "${DOCKER_MOUNTS[@]}" \
  --network host \
  "${DOCKER_ENV[@]}" \
  "$ANSIBLE_IMAGE" \
  ansible-playbook -i "/work/$INVENTORY" playbooks/telegram_vps_egress.yml "${LIMIT_OPT[@]}" "${ANSIBLE_EXTRA[@]}" "${EXTRA[@]}"
