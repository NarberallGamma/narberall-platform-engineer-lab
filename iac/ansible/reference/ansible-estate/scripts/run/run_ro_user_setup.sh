#!/usr/bin/env bash
# Создание read-only пользователя PostgreSQL (схема public) по плейбуку ro_user_setup.yaml.
# Запуск из корня каталога ansible: ./scripts/run/run_ro_user_setup.sh <db_name|all> --extra-vars "ro_user=... ro_password=..." [--check] [-v]
# SSH не используется (inventory localhost). Для удалённых хостов см. scripts/run/lib/docker_ssh.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-registry.example.com/platform/base-images/ansible:1.0}"
PLAYBOOK="playbooks/estate_databases/playbooks/ro_user_setup.yaml"

usage() {
  echo "Usage: $0 <db_name|all> --extra-vars 'ro_user=NAME ro_password=SECRET [pg_admin_password=...]' [ansible_args...]"
  echo ""
  echo "Examples:"
  echo "  $0 all --extra-vars 'ro_user=superset_main ro_password=... pg_admin_password=...'"
  echo "  $0 treasury_contract --extra-vars 'ro_user=superset_main ro_password=... pg_admin_password=...'"
  echo "  $0 all --extra-vars 'ro_user=superset_main ro_password=...' --check"
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

echo "=== RO USER SETUP (PostgreSQL read-only) ==="
echo "Playbook: $PLAYBOOK_ABS"
echo "Database(s): $DB_DESCRIPTION"
echo ""
echo "Пароли: ro_user, ro_password обязательны; pg_admin_password — из vars плейбука или --extra-vars."
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
echo "SUCCESS: RO user setup for $DB_DESCRIPTION."
