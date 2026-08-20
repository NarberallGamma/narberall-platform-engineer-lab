#!/usr/bin/env bash
# Legacy-миграция host nginx/keepalived -> docker edge-lb (/docker/apps/edge-lb)
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=lib/docker_ssh.sh
source "$(dirname "$0")/lib/docker_ssh.sh"
# shellcheck source=lib/control_node_env.sh
source "$(dirname "$0")/lib/control_node_env.sh"

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-registry.example.com/platform/base-images/ansible:1.0}"
PLAYBOOK="playbooks/migrate_edge_lb_legacy.yml"
INVENTORY=""
LIMIT_ARG=""
SCOPE_SPECIFIED=""
SSH_KEY_PATH=""
USE_SSH_AGENT=""
ASK_PASS=""
EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --)
      shift
      while [[ $# -gt 0 ]]; do
        EXTRA+=("$1")
        shift
      done
      break
      ;;
    --prod)    INVENTORY="inventories/prod/hosts.ini"; shift ;;
    --preprod) INVENTORY="inventories/preprod/hosts.ini"; shift ;;
    --all)     SCOPE_SPECIFIED=1; shift ;;
    --limit)   LIMIT_ARG="$2"; SCOPE_SPECIFIED=1; shift 2 ;;
    --ssh-key|-k) SSH_KEY_PATH="$2"; shift 2 ;;
    --ssh-agent)  USE_SSH_AGENT=1; shift ;;
    --ask-pass)   ASK_PASS=1; shift ;;
    help|-h|--help)
      cat <<'EOF'
Usage: run_migrate_edge_lb_legacy.sh --prod|--preprod (--all | --limit HOST) [options] [-- ansible-args]

Legacy-миграция LB: host nginx + keepalived -> docker edge-lb.
Краткий downtime на 443/VIP. См. playbooks/migrate_edge_lb_legacy.yml

Prod порядок: сначала BACKUP estate-prod-lb-2, затем MASTER estate-prod-lb-1

Examples:
  ./scripts/run/run_migrate_edge_lb_legacy.sh --preprod --limit estate-preprod-lb-1 --ssh-key ~/.ssh/estate-preprod-ecs-key.pem
  ./scripts/run/run_migrate_edge_lb_legacy.sh --prod --limit estate-prod-lb-2 --ssh-key ~/.ssh/estate-prod-ecs-key.pem
  ./scripts/run/run_migrate_edge_lb_legacy.sh --prod --limit estate-prod-lb-1 -- --tags prepare
EOF
      exit 0
      ;;
    *) EXTRA+=("$1"); shift ;;
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

DOCKER_MOUNTS=()
DOCKER_ENV=(-e ANSIBLE_CONFIG=/work/ansible.cfg -e ANSIBLE_ROLES_PATH=/work/roles)
ANSIBLE_EXTRA=()
docker_ssh_apply
control_node_env_apply

LIMIT_OPT=()
[[ -n "$LIMIT_ARG" ]] && LIMIT_OPT=(--limit "$LIMIT_ARG")

docker run --rm -it \
  -v "$(pwd):/work" -w /work \
  "${DOCKER_MOUNTS[@]}" \
  --network host \
  "${DOCKER_ENV[@]}" \
  "$ANSIBLE_IMAGE" \
  ansible-playbook -i "/work/$INVENTORY" "$PLAYBOOK" "${LIMIT_OPT[@]}" "${ANSIBLE_EXTRA[@]}" "${EXTRA[@]}"
