#!/usr/bin/env bash
# Настройка schema_flyway и разграничение прав (DDL/Flyway — schema_flyway, DML + REPLICATION — treasury_user).
# Выполнять из корня каталога ansible: ./scripts/run/run_schema_flyway_setup.sh <db_name|all> [--check] [-v] ...
# Пароли: задать в playbooks/estate_databases/playbooks/schema_flyway_setup.yaml или передать в --extra-vars.
# SSH не используется (inventory localhost). Для удалённых хостов см. scripts/run/lib/docker_ssh.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-registry.example.com/platform/base-images/ansible:1.0}"
PLAYBOOK="playbooks/estate_databases/playbooks/schema_flyway_setup.yaml"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <db_name|all> [ansible_extra_args...]"
  echo ""
  echo "Examples:"
  echo "  $0 all               # all databases (default list)"
  echo "  $0 treasury_contract      # single database"
  echo "  $0 all --check"
  echo "  $0 treasury_web -v"
  echo ""
  echo "Passwords: set pg_admin_password and schema_flyway_password in the playbook vars,"
  echo "  or pass via: --extra-vars \"pg_admin_password=... schema_flyway_password=...\""
  exit 1
fi

DB_ARG=$1
shift || true

if [[ ! -f "$PLAYBOOK" ]]; then
  echo "ERROR: Playbook not found: $PLAYBOOK"
  exit 1
fi

PLAYBOOK_ABS="$(cd "$(dirname "$PLAYBOOK")" && pwd)/$(basename "$PLAYBOOK")"

# Скалярные ключи только из блока vars: первого play (не из pre_tasks/roles и не из комментариев).
extract_scalar_from_playbook_vars() {
  local key="$1"
  sed 's/\r$//' "$PLAYBOOK" | awk -v key="$key" '
    /^  vars:/ { invars=1; next }
    invars && /^  [a-zA-Z_]/ && !/^    / { invars=0 }
    invars && $0 ~ "^    " key ":" {
      sub("^    " key ":[[:space:]]*", "");
      gsub(/^[[:space:]]*["'\'']|["'\''][[:space:]]*$/, "");
      gsub(/[[:space:]]+$/, "");
      print;
      exit
    }
  '
}

# Количество элементов в default_databases (только из vars:).
count_default_databases_in_playbook() {
  sed 's/\r$//' "$PLAYBOOK" | awk '
    /^    default_databases:/ { indb=1; next }
    indb && /^  [a-zA-Z_]/ { indb=0 }
    indb && /^      -/ { c++ }
    END { print c+0 }
  '
}

PG_HOST=$(extract_scalar_from_playbook_vars "pg_host")
PG_PORT=$(extract_scalar_from_playbook_vars "pg_port")
PG_ADMIN_USER=$(extract_scalar_from_playbook_vars "pg_admin_user")
treasury_USER=$(extract_scalar_from_playbook_vars "treasury_user")
treasury_FLYWAY=$(extract_scalar_from_playbook_vars "schema_flyway")
DEFAULT_DB_COUNT=$(count_default_databases_in_playbook)

if [[ -z "$PG_HOST" ]] || [[ -z "$PG_PORT" ]] || [[ -z "$PG_ADMIN_USER" ]] || [[ -z "$treasury_USER" ]] || [[ -z "$treasury_FLYWAY" ]]; then
  echo "ERROR: Could not extract vars from $PLAYBOOK (pg_host, pg_port, pg_admin_user, treasury_user, schema_flyway)"
  exit 1
fi

if [[ "$DB_ARG" == "all" ]]; then
  EXTRA_VARS=""
  DB_DESCRIPTION="all databases from default list (${DEFAULT_DB_COUNT} DBs: default_databases in playbook)"
  if [[ "${DEFAULT_DB_COUNT}" -eq 0 ]]; then
    echo "WARNING: в плейбуке не найден список default_databases (0 строк «-»). Проверить YAML."
  fi
else
  EXTRA_VARS="db_name=$DB_ARG"
  DB_DESCRIPTION="database '$DB_ARG'"
fi

echo "=== treasury_FLYWAY SETUP ==="
echo "Playbook (источник pg_* / default_databases): $PLAYBOOK_ABS"
echo "Database(s): $DB_DESCRIPTION"
echo "PostgreSQL (из vars плейбука): ${PG_HOST}:${PG_PORT}"
echo "Admin user (из vars): ${PG_ADMIN_USER}"
echo ""
echo "This will create/use user $treasury_FLYWAY, change schema/object ownership and grant permissions (treasury_user: DML + REPLICATION)."
echo ""
read -p "Continue? (yes/no): " confirmation
if [[ "$confirmation" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

ANSIBLE_ARGS=(-i "localhost," "$PLAYBOOK")
[[ -n "$EXTRA_VARS" ]] && ANSIBLE_ARGS+=(--extra-vars "$EXTRA_VARS")
ANSIBLE_ARGS+=("$@")

# Образ ansible:1.0 должен собираться с community.postgresql и community.general (см. base-images/ansible).
# Если ошибка "couldn't resolve module community.postgresql.postgresql_user" — обновите образ: docker pull $ANSIBLE_IMAGE
docker run --rm -it \
  -v "$(pwd):/work" -w /work \
  --network host \
  -e ANSIBLE_CONFIG=/work/ansible.cfg \
  -e ANSIBLE_ROLES_PATH=/work/roles:/work/playbooks/estate_databases/playbooks/roles \
  "$ANSIBLE_IMAGE" \
  ansible-playbook "${ANSIBLE_ARGS[@]}"

echo ""
echo "SUCCESS: schema_flyway setup done for $DB_DESCRIPTION."
