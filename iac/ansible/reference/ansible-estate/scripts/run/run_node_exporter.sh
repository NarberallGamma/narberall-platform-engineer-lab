#!/usr/bin/env bash
# Node Exporter: деплой на внешние серверы. Обязательно: окружение (--prod/--preprod) и scope (--all или --limit HOST).
#
# SSH-ключ с passphrase: eval "$(ssh-agent -s)" && ssh-add ~/.ssh/your_key
#   ./scripts/run/run_node_exporter.sh deploy --prod --limit HOST --ssh-key ~/.ssh/your_key --ssh-agent
# Подробнее: scripts/run/lib/docker_ssh.sh
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
PLAYBOOK="playbooks/node-exporter-deploy.yml"
EXTRA=()

# Парсинг: первый не-опция = команда, затем обязательны --prod/--preprod и --all/--limit
COMMAND=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prod)    INVENTORY="inventories/prod/hosts.ini"; shift ;;
    --preprod) INVENTORY="inventories/preprod/hosts.ini"; shift ;;
    --all)     SCOPE_SPECIFIED=1; shift ;;
    --limit)   LIMIT_ARG="$2"; SCOPE_SPECIFIED=1; shift 2 ;;
    --ssh-key|-k) SSH_KEY_PATH="$2"; shift 2 ;;
    --ssh-agent)  USE_SSH_AGENT=1; shift ;;
    --ask-pass)   ASK_PASS=1; shift ;;
    deploy|status|help)
      [[ -z "$COMMAND" ]] && COMMAND="$1"
      shift
      ;;
    *)         EXTRA+=("$1"); shift ;;
  esac
done

if [[ -z "$COMMAND" ]]; then
  echo "Usage: $0 (deploy|status|help) --prod|--preprod (--all | --limit HOST) [--ssh-key PATH] [--ssh-agent] [extra...]"
  echo ""
  echo "Commands: deploy | status | help"
  echo "Required: --prod or --preprod (environment), --all or --limit HOST (scope)"
  echo "Examples:"
  echo "  $0 deploy --prod --all"
  echo "  $0 deploy --preprod --limit estate-preprod-gitlab --ssh-key ~/.ssh/key --ssh-agent"
  echo "  $0 status --prod --limit estate-prod-gitlab"
  exit 1
fi

if [[ "$COMMAND" != "help" ]]; then
  if [[ -z "$INVENTORY" ]]; then
    echo "ERROR: Specify environment: --prod or --preprod"
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
fi

DOCKER_MOUNTS=()
DOCKER_ENV=(-e ANSIBLE_CONFIG=/work/ansible.cfg -e ANSIBLE_ROLES_PATH=/work/roles)
ANSIBLE_EXTRA=()
docker_ssh_apply
control_node_env_apply
if [[ -z "$SSH_KEY_PATH" && -z "$USE_SSH_AGENT" && -z "$ASK_PASS" && -d "$HOME/.ssh" ]]; then
  DOCKER_MOUNTS+=(-v "$HOME/.ssh:/root/.ssh:ro")
fi

# При монтировании $HOME/.ssh в /root/.ssh ssh от root отклоняет чужой config (StrictModes).
# Не читать user config — ключ и IdentitiesOnly из инвентаря / --ssh-key.
SSH_ANSIBLE_EXTRA=(-e "ansible_ssh_common_args='-o IdentitiesOnly=yes -F /dev/null'")
if [[ -n "$USE_SSH_AGENT" && -z "$SSH_KEY_PATH" ]]; then
  SSH_ANSIBLE_EXTRA=()
fi

run_ansible() {
  docker run --rm ${ANSIBLE_DOCKER_TTY:--it} \
    -v "$(pwd):/work" -w /work \
    "${DOCKER_MOUNTS[@]}" \
    --network host \
    "${DOCKER_ENV[@]}" \
    "$ANSIBLE_IMAGE" \
    "$@"
}

deploy_node_exporter() {
  echo "Starting node-exporter deployment..."
  LIMIT_OPT=()
  [[ -n "$LIMIT_ARG" ]] && LIMIT_OPT=(--limit "$LIMIT_ARG")
  run_ansible ansible-playbook -i "$INVENTORY" "$PLAYBOOK" "${LIMIT_OPT[@]}" "${SSH_ANSIBLE_EXTRA[@]}" "${ANSIBLE_EXTRA[@]}" "${EXTRA[@]}"
  echo "SUCCESS: node-exporter deployment completed."
}

check_status() {
  echo "=== NODE-EXPORTER STATUS ==="
  LIMIT_OPT=()
  [[ -n "$LIMIT_ARG" ]] && LIMIT_OPT=(--limit "$LIMIT_ARG")
  echo "Container status:"
  run_ansible ansible monitoring_servers -i "$INVENTORY" "${LIMIT_OPT[@]}" "${SSH_ANSIBLE_EXTRA[@]}" "${ANSIBLE_EXTRA[@]}" -m shell -a "docker ps --filter name=node-exporter; docker compose -f /docker/apps/node-exporter/docker-compose.yml ps 2>/dev/null || docker-compose -f /docker/apps/node-exporter/docker-compose.yml ps 2>/dev/null || true" --one-line 2>/dev/null || echo "Container not found"
  echo "Metrics endpoint:"
  run_ansible ansible monitoring_servers -i "$INVENTORY" "${LIMIT_OPT[@]}" "${SSH_ANSIBLE_EXTRA[@]}" "${ANSIBLE_EXTRA[@]}" -m uri -a "url=http://{{ ansible_host }}:9100/metrics validate_certs=no" --one-line 2>/dev/null || echo "Metrics endpoint not available"
}

case "$COMMAND" in
  deploy)   deploy_node_exporter ;;
  status)   check_status ;;
  help)
    echo "Node Exporter: deploy | status | help"
    echo "Required: --prod|--preprod and --all|--limit HOST"
    echo "SSH: --ssh-key PATH [--ssh-agent] (passphrase: ssh-add перед запуском)"
    echo "Examples: $0 deploy --prod --all | $0 status --preprod --limit HOST"
    ;;
  *)
    echo "ERROR: Unknown command: $COMMAND"
    exit 1
    ;;
esac
