#!/usr/bin/env bash
# Nextcloud groupfolders. SSH key with a passphrase: eval "$(ssh-agent -s)" && ssh-add ~/.ssh/your_key
#   ./scripts/run/run_nextcloud_groupfolders.sh --profile nextcloud-dev --limit HOST --ssh-key ~/.ssh/your_key --ssh-agent
# Details: scripts/run/lib/docker_ssh.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=lib/docker_ssh.sh
source "$(dirname "$0")/lib/docker_ssh.sh"
# Load Vault variables from the control node (created by the pipeline from CI Variables into /ansible/.env.vault).
[ -f .env.vault ] && source .env.vault

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-git.example.com/platform-infra/base-images/ansible:1.0}"

# One of: --limit <inventory host> OR --profile nextcloud-dev|nextcloud-prod|regul (then the default host is chosen: see the resolve block below; must match group_vars nextcloud_profile_default_inventory_host).
# Profile: --profile sets matrix/WebDAV/Vault (nextcloud_matrix_profile_by_host is applied for this run). Can be combined with --limit.
# Single-client mode: pass the client name as an argument (quote names with spaces).
# All-clients mode: --all-clients — folder list from WebDAV, apply matrix ACLs to all (client_name not needed).
# All-clients + create folders from the matrix: --all-clients-create — same plus idempotent MKCOL per client, then ACL.
# ACL-only for one client: --permissions-only and a client name — replay matrix ACLs without WebDAV MKCOL (single-folder test).
# LDAP reset mode: --ldap-reset — only occ ldap:reset-group for groups in nextcloud_ldap_reset_groups (client_name not needed).
# Example (one client, dev): ./run_nextcloud_groupfolders.sh --profile nextcloud-dev "Acme LLC"
# Example (Regul, host from profile app-02.example.com): ./run_nextcloud_groupfolders.sh --profile regul "Client name"
# Example (--limit without changing the group_vars profile): ./run_nextcloud_groupfolders.sh --limit nextcloud-dev.example.com "Acme …"
# Example (all clients):  ./run_nextcloud_groupfolders.sh --profile nextcloud-dev --all-clients
# Example (all clients, MKCOL+ACL): ./run_nextcloud_groupfolders.sh --profile regul --all-clients-create
# Example (ACL only for one, no MKCOL): ./run_nextcloud_groupfolders.sh --profile regul --permissions-only "Client name"
# Example (LDAP reset):   ./run_nextcloud_groupfolders.sh --profile nextcloud-dev --ldap-reset
# Parallelism (Ansible throttle): --mkcol-threads N, --occ-threads N (override group_vars; without flags — values from group_vars/defaults).
# Example: ./run_nextcloud_groupfolders.sh --profile nextcloud-dev --mkcol-threads 4 --occ-threads 4 "Acme …"
INV="inventories/hosts.ini"
LIMIT_HOST=""
MATRIX_PROFILE=""
SSH_KEY_PATH=""
ASK_PASS=""
USE_SSH_AGENT=""
EXTRA=()
CLIENT_NAME_ARG=""
REAPPLY_ALL_CLIENTS=""
ALL_CLIENTS_MKCOL=""
LDAP_RESET=""
PERMISSIONS_ONLY=""
NC_CONCURRENCY_MKCOL=""
NC_CONCURRENCY_OCC=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit|-L)        LIMIT_HOST="$2"; shift 2 ;;
    --profile|-p)      MATRIX_PROFILE="$2"; shift 2 ;;
    --all-clients|-A)  REAPPLY_ALL_CLIENTS=1; shift ;;
    --all-clients-create|--all-clients-mkcol) ALL_CLIENTS_MKCOL=1; REAPPLY_ALL_CLIENTS=1; shift ;;
    --permissions-only|--acl-only) PERMISSIONS_ONLY=1; shift ;;
    --ldap-reset)      LDAP_RESET=1; shift ;;
    --mkcol-threads|--mkcol-concurrency) NC_CONCURRENCY_MKCOL="$2"; shift 2 ;;
    --occ-threads|--occ-concurrency)     NC_CONCURRENCY_OCC="$2"; shift 2 ;;
    --local|-l)        INV="inventories/localhost/hosts.ini"; shift ;;
    --remote|-r)      INV="inventories/hosts.ini"; shift ;;
    --ssh-key|-k)     SSH_KEY_PATH="$2"; shift 2 ;;
    --ssh-agent)      USE_SSH_AGENT=1; shift ;;
    --ask-pass)       ASK_PASS=1; shift ;;
    -e)               EXTRA+=("$1"); shift; [[ $# -gt 0 ]] && EXTRA+=("$1"); shift ;;
    *)
      if [[ -z "$CLIENT_NAME_ARG" ]] && [[ -z "$REAPPLY_ALL_CLIENTS" ]] && [[ -z "$LDAP_RESET" ]] && [[ "$1" != -* ]]; then
        CLIENT_NAME_ARG="$1"
        shift
      else
        EXTRA+=("$1"); shift
      fi
      ;;
  esac
done

if [[ -n "$PERMISSIONS_ONLY" ]] && [[ -n "$REAPPLY_ALL_CLIENTS" ]]; then
  echo "Error: --permissions-only cannot be combined with --all-clients / --all-clients-create." >&2
  exit 1
fi
if [[ -n "$PERMISSIONS_ONLY" ]] && [[ -n "$ALL_CLIENTS_MKCOL" ]]; then
  echo "Error: --permissions-only cannot be combined with --all-clients-create." >&2
  exit 1
fi
if [[ -n "$PERMISSIONS_ONLY" ]] && [[ -n "$LDAP_RESET" ]]; then
  echo "Error: --permissions-only cannot be combined with --ldap-reset." >&2
  exit 1
fi
# When the client name is a single argument — write it to a file and pass -e @file (Docker args split on spaces)
CLIENT_VARS_FILE=""
MATRIX_VARS_FILE=""
if [[ -n "$CLIENT_NAME_ARG" ]]; then
  CLIENT_VARS_FILE=".ansible_client_vars.json"
  escaped="${CLIENT_NAME_ARG//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  printf '{"client_name": "%s"}\n' "$escaped" > "$CLIENT_VARS_FILE"
  EXTRA=(-e "@${CLIENT_VARS_FILE}" "${EXTRA[@]}")
fi
# All-clients mode: nextcloud_reapply_all_clients_enabled; with --all-clients-create also nextcloud_reapply_all_clients_mkcol_enabled
if [[ -n "$REAPPLY_ALL_CLIENTS" ]]; then
  EXTRA=(-e "nextcloud_reapply_all_clients_enabled=true" "${EXTRA[@]}")
fi
if [[ -n "$ALL_CLIENTS_MKCOL" ]]; then
  EXTRA=(-e "nextcloud_reapply_all_clients_mkcol_enabled=true" "${EXTRA[@]}")
fi
# ACL-only for one client: nextcloud_reapply_permissions_only without MKCOL
if [[ -n "$PERMISSIONS_ONLY" ]]; then
  EXTRA=(-e "nextcloud_reapply_permissions_only=true" "${EXTRA[@]}")
fi
# LDAP reset mode: only occ ldap:reset-group for groups from group_vars (client_name is not passed)
if [[ -n "$LDAP_RESET" ]]; then
  EXTRA=(-e "nextcloud_ldap_reset_groups_enabled=true" "${EXTRA[@]}")
fi

# When --profile is set without --limit: pick the inventory host (must match inventories/hosts.ini and group_vars/nextcloud_profile_default_inventory_host)
if [[ -z "$LIMIT_HOST" ]] && [[ -n "$MATRIX_PROFILE" ]]; then
  case "$MATRIX_PROFILE" in
    nextcloud-dev)
      LIMIT_HOST="nextcloud-dev.example.com"
      ;;
    nextcloud-prod)
      LIMIT_HOST="nextcloud-prod-oc3.example.com"
      ;;
    regul)
      LIMIT_HOST="app-02.example.com"
      ;;
    *)
      echo "Error: unknown --profile for auto-host: ${MATRIX_PROFILE} (expected nextcloud-dev, nextcloud-prod, or regul). Pass --limit explicitly or extend the resolve block in the script." >&2
      exit 1
      ;;
  esac
fi

if [[ -z "$LIMIT_HOST" ]]; then
  echo "Error: set --limit <inventory host> or --profile nextcloud-dev|nextcloud-prod|regul Example: --profile nextcloud-dev \"Acme …\"" >&2
  exit 1
fi

if [[ -n "$NC_CONCURRENCY_MKCOL" ]] && ! [[ "$NC_CONCURRENCY_MKCOL" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: --mkcol-threads expects an integer >= 1 (got: ${NC_CONCURRENCY_MKCOL})" >&2
  exit 1
fi
if [[ -n "$NC_CONCURRENCY_OCC" ]] && ! [[ "$NC_CONCURRENCY_OCC" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: --occ-threads expects an integer >= 1 (got: ${NC_CONCURRENCY_OCC})" >&2
  exit 1
fi

# Explicit matrix profile for the chosen --limit: via a JSON file so Ansible receives a dict, not a str
# (inline -e nextcloud_matrix_profile_by_host={...} after docker/ansible often becomes a string → [...] lookup error on inventory_hostname).
if [[ -n "$MATRIX_PROFILE" ]]; then
  case "$MATRIX_PROFILE" in
    nextcloud-dev|nextcloud-prod|regul)
      MATRIX_VARS_FILE=".ansible_matrix_profile_by_host.json"
      printf '{"nextcloud_matrix_profile_by_host":{"%s":"%s"}}\n' "$LIMIT_HOST" "$MATRIX_PROFILE" > "$MATRIX_VARS_FILE"
      EXTRA=(-e "@${MATRIX_VARS_FILE}" "${EXTRA[@]}")
      ;;
    *)
      echo "Error: --profile: allowed values are nextcloud-dev, nextcloud-prod, or regul (got: ${MATRIX_PROFILE})" >&2
      exit 1
      ;;
  esac
fi

_NC_GF_CLEANUP=()
[[ -n "${CLIENT_VARS_FILE:-}" ]] && [[ -f "$CLIENT_VARS_FILE" ]] && _NC_GF_CLEANUP+=("$CLIENT_VARS_FILE")
[[ -n "${MATRIX_VARS_FILE:-}" ]] && [[ -f "$MATRIX_VARS_FILE" ]] && _NC_GF_CLEANUP+=("$MATRIX_VARS_FILE")
if ((${#_NC_GF_CLEANUP[@]} > 0)); then
  trap 'rm -f "${_NC_GF_CLEANUP[@]}"' EXIT
fi

# MKCOL/OCC parallelism: append to EXTRA — overrides group_vars when passed explicitly
[[ -n "$NC_CONCURRENCY_MKCOL" ]] && EXTRA+=(-e "nextcloud_concurrency_mkcol=${NC_CONCURRENCY_MKCOL}")
[[ -n "$NC_CONCURRENCY_OCC" ]] && EXTRA+=(-e "nextcloud_concurrency_occ=${NC_CONCURRENCY_OCC}")

if [[ -n "$PERMISSIONS_ONLY" ]] && [[ -z "$CLIENT_NAME_ARG" ]]; then
  echo "Error: --permissions-only requires a client name, for example: $0 --profile regul --permissions-only \"Client name\"" >&2
  exit 1
fi

if [[ -z "$CLIENT_NAME_ARG" ]] && [[ -z "$REAPPLY_ALL_CLIENTS" ]] && [[ -z "$LDAP_RESET" ]] && [[ -z "$PERMISSIONS_ONLY" ]]; then
  echo "Error: pass a client name, --all-clients, --all-clients-create, or --ldap-reset. Example: $0 --profile nextcloud-dev \"Acme LLC\" | $0 --profile regul \"…\" | $0 --limit nextcloud-dev.example.com …" >&2
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

# Playbook output log in artifacts/logs (playbook name + date/time) for debugging
LOG_DIR="artifacts/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/nextcloud_groupfolders_$(date +%Y-%m-%d_%H-%M-%S).log"
echo "Output log: $LOG_FILE" >&2

# Interactive terminal run — -it for readable output; n8n over SSH has no TTY — omit -it
DOCKER_TTY=""
[[ -t 0 ]] && [[ -t 1 ]] && DOCKER_TTY="-it"
docker run --rm $DOCKER_TTY \
  -v "$(pwd):/work" -w /work \
  "${DOCKER_MOUNTS[@]}" \
  "${VAULT_ENV[@]}" \
  "${DOCKER_ENV[@]}" \
  --network host \
  "$ANSIBLE_IMAGE" \
  ansible-playbook -i "/work/$INV" playbooks/nextcloud_groupfolders.yml --limit "$LIMIT_HOST" "${ANSIBLE_EXTRA[@]}" "${EXTRA[@]}" 2>&1 | tee "$LOG_FILE"
