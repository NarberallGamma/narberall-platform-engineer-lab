#!/usr/bin/env bash
# PostgreSQL RW user: GRANT DML on data (no OWNER, no CREATE on the schema).
# Playbook: playbooks/estate_databases/playbooks/rw_user_setup.yaml
# Run from the ansible directory root:
#   ./scripts/run/run_rw_user_setup.sh <db_name|all> --extra-vars "rw_user=... rw_password=... pg_admin_password=..." [--check] [-v]
# Account already in the cloud (do not change the password):
#   ./scripts/run/run_rw_user_setup.sh all --extra-vars "rw_user=estate_analyst manage_password=false pg_admin_password=..."
# SSH is not used (inventory localhost).
set -euo pipefail
cd "$(dirname "$0")/../.."

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-registry.example.com/platform/base-images/ansible:1.0}"
PLAYBOOK="playbooks/estate_databases/playbooks/rw_user_setup.yaml"

usage() {
  echo "Usage: $0 <db_name|all> --extra-vars 'rw_user=NAME [rw_password=SECRET] [manage_password=true|false] [pg_admin_password=...]' [ansible_args...]"
  echo ""
  echo "Examples:"
  echo "  $0 all --extra-vars 'rw_user=migration_tool rw_password=... pg_admin_password=...'"
  echo "  $0 treasury_contract --extra-vars 'rw_user=migration_tool rw_password=... pg_admin_password=...'"
  echo "  $0 all --extra-vars 'rw_user=estate_analyst manage_password=false pg_admin_password=...'"
  echo "  $0 all --extra-vars 'rw_user=migration_tool rw_password=... pg_admin_password=...' --check"
  exit 1
}

if [[ $# -eq 0 ]]; then
  usage
fi

DB_ARG=$1
shift || true

if [[ ! -f "$PLAYBOOK" ]]; then
  echo "ERROR: Playbook not found: $PLAYBOOK"
  exit 1
fi

PLAYBOOK_ABS="$(cd "$(dirname "$PLAYBOOK")" && pwd)/$(basename "$PLAYBOOK")"

if [[ "$DB_ARG" == "all" ]]; then
  EXTRA_VARS_DB=""
  DB_DESCRIPTION="all databases from default list in playbook"
else
  EXTRA_VARS_DB="db_name=$DB_ARG"
  DB_DESCRIPTION="database '$DB_ARG'"
fi

echo "=== RW USER SETUP (PostgreSQL GRANT DML, no OWNER) ==="
echo "Playbook: $PLAYBOOK_ABS"
echo "Database(s): $DB_DESCRIPTION"
echo ""
echo "rw_user is required; rw_password is required when manage_password=true (default)."
echo "manage_password=false: GRANTs only, account password is left unchanged (role must already exist in RDS)."
echo "pg_admin_password: from playbook vars or --extra-vars."
echo "default_databases does not include openobserve."
echo ""
read -p "Continue? (yes/no): " confirmation
if [[ "$confirmation" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

ANSIBLE_ARGS=(-i "localhost," "$PLAYBOOK")
[[ -n "$EXTRA_VARS_DB" ]] && ANSIBLE_ARGS+=(--extra-vars "$EXTRA_VARS_DB")
ANSIBLE_ARGS+=("$@")

docker run --rm -it \
  -v "$(pwd):/work" -w /work \
  --network host \
  -e ANSIBLE_CONFIG=/work/ansible.cfg \
  -e ANSIBLE_ROLES_PATH=/work/roles:/work/playbooks/estate_databases/playbooks/roles \
  "$ANSIBLE_IMAGE" \
  ansible-playbook "${ANSIBLE_ARGS[@]}"

echo ""
echo "SUCCESS: RW user setup for $DB_DESCRIPTION."
