#!/usr/bin/env bash
# RW-пользователь PostgreSQL: GRANT DML на данные (без OWNER, без CREATE на схеме).
# Плейбук: playbooks/estate_databases/playbooks/rw_user_setup.yaml
# Запуск из корня каталога ansible:
#   ./scripts/run/run_rw_user_setup.sh <db_name|all> --extra-vars "rw_user=... rw_password=... pg_admin_password=..." [--check] [-v]
# Учётка уже в облаке (пароль не менять):
#   ./scripts/run/run_rw_user_setup.sh all --extra-vars "rw_user=estate_analyst manage_password=false pg_admin_password=..."
# SSH не используется (inventory localhost).
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

echo "=== RW USER SETUP (PostgreSQL GRANT DML, без OWNER) ==="
echo "Playbook: $PLAYBOOK_ABS"
echo "Database(s): $DB_DESCRIPTION"
echo ""
echo "rw_user обязателен; rw_password обязателен при manage_password=true (по умолчанию)."
echo "manage_password=false: только GRANT, пароль учётки не меняется (роль должна существовать в RDS)."
echo "pg_admin_password: из vars плейбука или --extra-vars."
echo "default_databases не включает openobserve."
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
