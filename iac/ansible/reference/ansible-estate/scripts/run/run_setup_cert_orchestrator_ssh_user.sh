#!/usr/bin/env bash
# Bootstrap пользователя estate-cert-orchestrator на целевых хostах cert-orchestrator.
#   ./scripts/run/run_setup_cert_orchestrator_ssh_user.sh --preprod --all
#   ./scripts/run/run_setup_cert_orchestrator_ssh_user.sh --prod --limit estate-prod-gitlab
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
ASK_PASS=""
USE_SSH_AGENT=""
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
  echo "ERROR: Specify environment: --prod or --preprod"
  echo "Usage: $0 --prod|--preprod (--all | --limit HOST) [--ssh-key PATH] [--ssh-agent] [--ask-pass] [extra...]"
  exit 1
fi
if [[ -z "$SCOPE_SPECIFIED" ]]; then
  echo "ERROR: Specify scope: --all or --limit HOST"
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
LIMIT_OPT=(--limit cert_orchestrator_ssh_targets)
[[ -n "$LIMIT_ARG" ]] && LIMIT_OPT=(--limit "cert_orchestrator_ssh_targets:&${LIMIT_ARG}")

docker run --rm -it \
  -v "$(pwd):/work" -w /work \
  "${DOCKER_MOUNTS[@]}" \
  --network host \
  "${DOCKER_ENV[@]}" \
  "$ANSIBLE_IMAGE" \
  ansible-playbook -i "/work/$INVENTORY" playbooks/setup_cert_orchestrator_ssh_user.yml "${LIMIT_OPT[@]}" "${ANSIBLE_EXTRA[@]}" "${EXTRA[@]}"
