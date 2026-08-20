#!/usr/bin/env bash
# Docker app: один compose-сервис в /docker/apps/<slug> на любой VM из inventory
#
#   ./scripts/run/run_docker_app.sh deploy cert-monitoring --prod --limit estate-prod-gitlab
#   ./scripts/run/run_docker_app.sh deploy cert-orchestrator --preprod --limit estate-preprod-gitlab
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
APP_SLUG=""
PLAYBOOK=""
EXTRA=()
COMMAND=""

playbook_for_app() {
  case "$1" in
    cert-monitoring)           echo "playbooks/docker_app_cert_monitoring.yml" ;;
    cert-orchestrator)         echo "playbooks/docker_app_cert_orchestrator.yml" ;;
    cloud-hibernate-operator)  echo "playbooks/docker_app_cloud_hibernate_operator.yml" ;;
    gitlab-nginx)              echo "playbooks/docker_app_gitlab_nginx.yml" ;;
    edge-lb)                   echo "playbooks/docker_app_edge_lb.yml" ;;
    hsm-adapter)               echo "playbooks/docker_app_hsm_adapter.yml" ;;
    treasury-policy-gateway)   echo "playbooks/docker_app_treasury_policy_gateway.yml" ;;
    cryptopro)             echo "playbooks/docker_app_cryptopro.yml" ;;
    *) return 1 ;;
  esac
}

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
    deploy|help)
      [[ -z "$COMMAND" ]] && COMMAND="$1"
      shift
      ;;
    cert-monitoring|cert-orchestrator|cloud-hibernate-operator|gitlab-nginx|edge-lb|hsm-adapter|treasury-policy-gateway|cryptopro)
      APP_SLUG="$1"
      shift
      ;;
    *)         EXTRA+=("$1"); shift ;;
  esac
done

if [[ -z "$COMMAND" ]]; then
  COMMAND=help
fi

if [[ "$COMMAND" == "help" ]]; then
  cat <<'EOF'
Usage: run_docker_app.sh deploy <app> --prod|--preprod (--all | --limit HOST) [options]

Apps:
  cert-monitoring
  cert-orchestrator
  cloud-hibernate-operator
  gitlab-nginx
  edge-lb
  hsm-adapter
  treasury-policy-gateway
  cryptopro

Каждое приложение: отдельный плейбук + inventory group (cert_monitoring, …, cryptopro_vm для hsm-adapter / policy-gateway / cryptopro на одной VM).
TLS hsm-adapter / policy-gateway / cryptopro: edge-lb vhost (не nginx на cryptopro VM). Секреты: DOCKER_APPS_VAULT_SECRETS.md

Options:
  --prod | --preprod     inventory
  --all | --limit HOST   scope
  --ssh-key PATH         SSH key for ansible
  --ssh-agent            ssh-agent for passphrase key
  --ask-pass             SSH password

  --                     аргументы ansible-playbook (например: -- -e key=val --check)

Examples:
  # С control node (estate-prod-gitlab / estate-preprod-gitlab): bootstrap-ключ .ssh/ansible_ssh_key, user ansible (host_vars)
  ./scripts/run/run_docker_app.sh deploy cert-monitoring --prod --limit estate-prod-gitlab
  ./scripts/run/run_docker_app.sh deploy cert-orchestrator --preprod --limit estate-preprod-gitlab
  ./scripts/run/run_docker_app.sh deploy cloud-hibernate-operator --prod --limit estate-prod-gitlab

  # С рабочей станции на другую VM: root + cloud key
  ./scripts/run/run_docker_app.sh deploy cert-monitoring --prod --limit SOME_HOST --ssh-key ~/.ssh/estate-prod-ecs-key.pem
EOF
  exit 0
fi

if [[ -z "$APP_SLUG" ]]; then
  echo "ERROR: Specify app: cert-monitoring | cert-orchestrator | cloud-hibernate-operator | gitlab-nginx | edge-lb | hsm-adapter | treasury-policy-gateway | cryptopro"
  exit 1
fi

PLAYBOOK="$(playbook_for_app "$APP_SLUG")" || {
  echo "ERROR: Unknown app: $APP_SLUG"
  exit 1
}

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
if [[ ! -f "$PLAYBOOK" ]]; then
  echo "ERROR: Playbook not found: $PLAYBOOK"
  exit 1
fi

DOCKER_MOUNTS=()
DOCKER_ENV=(-e ANSIBLE_CONFIG=/work/ansible.cfg -e ANSIBLE_ROLES_PATH=/work/roles)
ANSIBLE_EXTRA=()
docker_ssh_apply
control_node_env_apply

# Control node (/ansible на GitLab): bootstrap-ключ + user ansible (inventory [all:vars] root)
if [[ -f .ssh/ansible_ssh_key && -z "${SSH_KEY_PATH:-}" && -z "${USE_SSH_AGENT:-}" ]]; then
  ANSIBLE_EXTRA+=(-e ansible_user=ansible)
fi

LIMIT_OPT=()
[[ -n "$LIMIT_ARG" ]] && LIMIT_OPT=(--limit "$LIMIT_ARG")

# -t fails in CI / non-TTY (GitLab job); keep -it for interactive control-node use
DOCKER_TTY=(-i)
if [[ -t 0 && -z "${CI:-}" ]]; then
  DOCKER_TTY=(-it)
fi

docker run --rm "${DOCKER_TTY[@]}" \
  -v "$(pwd):/work" -w /work \
  "${DOCKER_MOUNTS[@]}" \
  --network host \
  "${DOCKER_ENV[@]}" \
  "$ANSIBLE_IMAGE" \
  ansible-playbook -i "/work/$INVENTORY" "$PLAYBOOK" "${LIMIT_OPT[@]}" "${ANSIBLE_EXTRA[@]}" "${EXTRA[@]}"
