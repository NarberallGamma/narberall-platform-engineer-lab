#!/usr/bin/env bash
# Пересоздание БД PostgreSQL через плейбук управления базами estate (estate_databases/restore).
# Выполнять из корня каталога ansible: ./scripts/run/run_db_restore.sh <db_name|all> [--check] [-v] ...
# ВНИМАНИЕ: удаляет указанные базы и все данные в них!
# SSH не используется (inventory localhost). Для удалённых хостов см. scripts/run/lib/docker_ssh.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-registry.example.com/platform/base-images/ansible:1.0}"
PLAYBOOK="playbooks/estate_databases/playbooks/restore.yaml"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <db_name|all> [ansible_extra_args...]"
  echo ""
  echo "Examples:"
  echo "  $0 treasury_onboarding"
  echo "  $0 all"
  echo "  $0 treasury_contract --check"
  echo "  $0 treasury_onboarding -v"
  echo ""
  echo "WARNING: This will DELETE all data in the specified database(s)!"
  exit 1
fi

DB_ARG=$1
shift || true

if [[ ! -f "$PLAYBOOK" ]]; then
  echo "ERROR: Playbook not found: $PLAYBOOK"
  exit 1
fi

extract_var_from_playbook() {
  local var_name=$1
  grep -E "^\s*${var_name}:" "$PLAYBOOK" | \
    sed -E "s/^\s*${var_name}:\s*//" | \
    sed -E "s/^[\"'](.*)[\"']\s*$/\1/" | \
    sed 's/\s*$//' | head -1
}

PG_HOST=$(extract_var_from_playbook "pg_host")
PG_PORT=$(extract_var_from_playbook "pg_port")
PG_ADMIN_USER=$(extract_var_from_playbook "pg_admin_user")
DB_OWNER=$(extract_var_from_playbook "treasury_user")

if [[ -z "$PG_HOST" ]] || [[ -z "$PG_PORT" ]] || [[ -z "$PG_ADMIN_USER" ]] || [[ -z "$DB_OWNER" ]]; then
  echo "ERROR: Could not extract vars from $PLAYBOOK (pg_host, pg_port, pg_admin_user, treasury_user)"
  exit 1
fi

if [[ "$DB_ARG" == "all" ]]; then
  EXTRA_VARS=""
  DB_DESCRIPTION="all databases from default list"
else
  EXTRA_VARS="db_name=$DB_ARG"
  DB_DESCRIPTION="database '$DB_ARG'"
fi

echo "=== DATABASE RESTORE ==="
echo "Database(s): $DB_DESCRIPTION"
echo "Host: ${PG_HOST}:${PG_PORT}"
echo "Admin: ${PG_ADMIN_USER}"
echo "Playbook: $PLAYBOOK"
echo ""
echo "This will DELETE the database(s) and all data!"
echo ""
read -p "Continue? (yes/no): " confirmation
if [[ "$confirmation" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

ANSIBLE_ARGS=(-i "localhost," "$PLAYBOOK")
[[ -n "$EXTRA_VARS" ]] && ANSIBLE_ARGS+=(--extra-vars "$EXTRA_VARS")
ANSIBLE_ARGS+=("$@")

docker run --rm -it \
  -v "$(pwd):/work" -w /work \
  --network host \
  -e ANSIBLE_CONFIG=/work/ansible.cfg \
  -e ANSIBLE_ROLES_PATH=/work/roles:/work/playbooks/estate_databases/playbooks/roles \
  "$ANSIBLE_IMAGE" \
  ansible-playbook "${ANSIBLE_ARGS[@]}"

echo ""
echo "SUCCESS: $DB_DESCRIPTION restored."
