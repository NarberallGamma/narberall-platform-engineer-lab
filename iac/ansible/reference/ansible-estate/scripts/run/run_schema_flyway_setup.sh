#!/usr/bin/env bash
# Configure schema_flyway and split privileges (DDL/Flyway — schema_flyway, DML + REPLICATION — treasury_user).
# Run from the ansible directory root: ./scripts/run/run_schema_flyway_setup.sh <db_name|all> [--check] [-v] ...
# Passwords: set in playbooks/estate_databases/playbooks/schema_flyway_setup.yaml or pass via --extra-vars.
# SSH is not used (inventory localhost). For remote hosts see scripts/run/lib/docker_ssh.sh
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

# Scalar keys only from the vars: block of the first play (not from pre_tasks/roles or comments).
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

# Count of items in default_databases (vars: only).
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
    echo "WARNING: default_databases list not found in the playbook (0 \"-\" rows). Check the YAML."
  fi
else
  EXTRA_VARS="db_name=$DB_ARG"
  DB_DESCRIPTION="database '$DB_ARG'"
fi

echo "=== treasury_FLYWAY SETUP ==="
echo "Playbook (source of pg_* / default_databases): $PLAYBOOK_ABS"
echo "Database(s): $DB_DESCRIPTION"
echo "PostgreSQL (from playbook vars): ${PG_HOST}:${PG_PORT}"
echo "Admin user (from vars): ${PG_ADMIN_USER}"
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

# The ansible:1.0 image must be built with community.postgresql and community.general (see base-images/ansible).
# If the error is "couldn't resolve module community.postgresql.postgresql_user" — pull a newer image: docker pull $ANSIBLE_IMAGE
docker run --rm -it \
  -v "$(pwd):/work" -w /work \
  --network host \
  -e ANSIBLE_CONFIG=/work/ansible.cfg \
  -e ANSIBLE_ROLES_PATH=/work/roles:/work/playbooks/estate_databases/playbooks/roles \
  "$ANSIBLE_IMAGE" \
  ansible-playbook "${ANSIBLE_ARGS[@]}"

echo ""
echo "SUCCESS: schema_flyway setup done for $DB_DESCRIPTION."
