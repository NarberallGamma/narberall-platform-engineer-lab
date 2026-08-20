#!/usr/bin/env bash
# Снятие GRANT-ов дополнительной роли PostgreSQL (без REASSIGN OWNED).
# Запуск: ./scripts/run/run_drop_db_user.sh <db_name|all> --extra-vars "drop_user=... [drop_role_after_cleanup=true] pg_admin_password=..." [--check]
set -euo pipefail
cd "$(dirname "$0")/../.."

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-registry.example.com/platform/base-images/ansible:1.0}"
PLAYBOOK="playbooks/estate_databases/playbooks/drop_db_user.yaml"

usage() {
  echo "Usage: $0 <db_name|all> --extra-vars 'drop_user=NAME [drop_role_after_cleanup=true] pg_admin_password=...' [ansible_args...]"
  echo ""
  echo "Examples:"
  echo "  $0 all --extra-vars 'drop_user=estate_0006 pg_admin_password=...'"
  echo "  $0 treasury_contract --extra-vars 'drop_user=estate_0006 pg_admin_password=...'"
  echo "  $0 all --extra-vars 'drop_user=estate_0006 drop_role_after_cleanup=true pg_admin_password=...' --check"
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

echo "=== DROP DB USER (revoke grants only, no REASSIGN) ==="
echo "Playbook: $PLAYBOOK_ABS"
echo "Database(s): $DB_DESCRIPTION"
echo ""
echo "Пароли: drop_user обязателен; pg_admin_password из vars или --extra-vars."
echo "DROP ROLE выполняется только при drop_role_after_cleanup=true."
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
echo "SUCCESS: drop_db_user for $DB_DESCRIPTION."
