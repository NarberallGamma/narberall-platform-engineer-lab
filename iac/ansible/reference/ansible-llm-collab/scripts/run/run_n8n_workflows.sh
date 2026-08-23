#!/usr/bin/env bash
# Sync n8n workflows from the repo (GitOps). Playbook runs on localhost — SSH is not used.
# For remote hosts see scripts/run/lib/docker_ssh.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
# Load Vault variables from the control node (created by the pipeline from CI Variables into /ansible/.env.vault).
[ -f .env.vault ] && source .env.vault

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-git.example.com/platform-infra/base-images/ansible:1.0}"

# Sync n8n workflows from the repo (GitOps). Playbook runs on localhost; n8n API is called over the network.
# --all / -A: sync all workflows from group_vars (n8n_workflows_to_sync).
# --workflow <name>: sync only that workflow (filename without .json in roles/n8n_workflows/files/workflows/).
# No arguments — same as --all.
# Example (all):    ./run_n8n_workflows.sh
# Example (all):    ./run_n8n_workflows.sh --all
# Example (one):    ./run_n8n_workflows.sh --workflow nextcloud_groupfolders_webhook
INV="inventories/localhost/hosts.ini"
EXTRA=()
SYNC_ALL=""
WORKFLOW_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all|-A)           SYNC_ALL=1; shift ;;
    --workflow|-w)      WORKFLOW_NAME="$2"; shift 2 ;;
    -e)                 EXTRA+=("$1"); shift; [[ $# -gt 0 ]] && EXTRA+=("$1"); shift ;;
    --help|-h)          echo "Usage: $0 [--all | --workflow NAME] [-e KEY=VAL ...]"; echo "  --all, -A       sync all workflows from group_vars"; echo "  --workflow, -w  sync only workflow NAME (file workflows/NAME.json)"; echo "  no arguments    same as --all"; exit 0 ;;
    *)
      EXTRA+=("$1"); shift
      ;;
  esac
done

# Single workflow: pass a one-item list (name as in workflows/NAME.json).
# All workflows: do not pass n8n_workflows_to_sync — taken from group_vars.
if [[ -n "$WORKFLOW_NAME" ]]; then
  EXTRA=(-e "n8n_workflows_to_sync=[\"$WORKFLOW_NAME\"]" "${EXTRA[@]}")
fi
# When --all is passed explicitly, do not override the list (from group_vars).

# Vault: pass VAULT_ADDR and VAULT_TOKEN from the environment into the container (for the n8n_init role).
VAULT_ENV=()
[[ -n "${VAULT_ADDR:-}" ]] && VAULT_ENV+=(-e "VAULT_ADDR=$VAULT_ADDR")
[[ -n "${VAULT_TOKEN:-}" ]] && VAULT_ENV+=(-e "VAULT_TOKEN=$VAULT_TOKEN")

# Playbook output log in artifacts/logs for debugging
LOG_DIR="artifacts/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/n8n_workflows_$(date +%Y-%m-%d_%H-%M-%S).log"
echo "Output log: $LOG_FILE" >&2

# Interactive terminal run — -it for readable output; cron/CI has no TTY — omit -it
DOCKER_TTY=""
[[ -t 0 ]] && [[ -t 1 ]] && DOCKER_TTY="-it"
docker run --rm $DOCKER_TTY \
  -v "$(pwd):/work" -w /work \
  "${VAULT_ENV[@]}" \
  --network host \
  -e ANSIBLE_CONFIG=/work/ansible.cfg \
  -e ANSIBLE_ROLES_PATH=/work/roles \
  "$ANSIBLE_IMAGE" \
  ansible-playbook -i "/work/$INV" playbooks/n8n_workflows.yml "${EXTRA[@]}" 2>&1 | tee "$LOG_FILE"
