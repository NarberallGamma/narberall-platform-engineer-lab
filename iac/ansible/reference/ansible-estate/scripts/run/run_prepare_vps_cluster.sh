#!/usr/bin/env bash
# Подготовка VPS blockchain egress (prepare_vps_cluster): firewall, Envoy, chrony.
# Обязательно: окружение (--prod) и scope (--all или --limit HOST).
# Перед прогоном заполнить vps_k8s_egress_source_cidrs в group_vars/vps_cluster.yml.
#
# Предусловие: prepare_servers на тех же хостах (Docker).
#
# SSH-ключ с passphrase:
#   eval "$(ssh-agent -s)" && ssh-add ~/.ssh/your_key
#   ./scripts/run/run_prepare_vps_cluster.sh --prod --limit estate-vps-cluster-01 --ssh-key ~/.ssh/your_key --ssh-agent
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
PLAYBOOK="playbooks/prepare_vps_cluster.yml"
COMMAND="deploy"
EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    deploy|status|help) COMMAND="$1"; shift ;;
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

if [[ "$COMMAND" == "help" ]]; then
  echo "Usage: $0 [deploy|status|help] --prod|--preprod (--all | --limit HOST) [options...]"
  echo ""
  echo "  deploy  — ansible-playbook prepare_vps_cluster.yml (по умолчанию)"
  echo "  status  — docker / ufw / listener :443 на vps_cluster"
  echo ""
  echo "Required: --prod and --all or --limit HOST"
  echo "Vars: group_vars/vps_cluster.yml (vps_k8s_egress_source_cidrs при enable_vps_firewall)"
  echo "Credentials: artifacts/vps_cluster_credentials/<hostname>/admin_vps_credentials.txt"
  exit 0
fi

if [[ -z "$INVENTORY" ]]; then
  echo "ERROR: Specify environment: --prod (vps_cluster в prod inventory)"
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
LIMIT_OPT=()
[[ -n "$LIMIT_ARG" ]] && LIMIT_OPT=(--limit "$LIMIT_ARG")

SSH_ANSIBLE_EXTRA=(-e "ansible_ssh_common_args='-o IdentitiesOnly=yes -F /dev/null'")
if [[ -n "$USE_SSH_AGENT" && -z "$SSH_KEY_PATH" ]]; then
  SSH_ANSIBLE_EXTRA=()
fi

run_ansible() {
  docker run --rm -it \
    -v "$(pwd):/work" -w /work \
    "${DOCKER_MOUNTS[@]}" \
    --network host \
    "${DOCKER_ENV[@]}" \
    "$ANSIBLE_IMAGE" \
    "$@"
}

case "$COMMAND" in
  deploy)
    echo "Starting prepare_vps_cluster..."
    run_ansible ansible-playbook -i "/work/$INVENTORY" "$PLAYBOOK" "${LIMIT_OPT[@]}" "${SSH_ANSIBLE_EXTRA[@]}" "${ANSIBLE_EXTRA[@]}" "${EXTRA[@]}"
    echo "SUCCESS: prepare_vps_cluster completed."
    ;;
  status)
    echo "=== VPS EGRESS STATUS ==="
    run_ansible ansible vps_cluster -i "/work/$INVENTORY" "${LIMIT_OPT[@]}" "${SSH_ANSIBLE_EXTRA[@]}" -m shell \
      -a 'echo "--- docker ---"; docker ps --filter name=envoy-egress; echo "--- ufw ---"; ufw status numbered 2>/dev/null | head -25; echo "--- :443 ---"; ss -tlnp | grep ":443" || echo "no listener"' \
      --one-line 2>/dev/null || true
    ;;
  *)
    echo "ERROR: Unknown command: $COMMAND (use deploy|status|help)"
    exit 1
    ;;
esac
