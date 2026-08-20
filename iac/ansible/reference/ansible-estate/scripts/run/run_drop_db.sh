#!/usr/bin/env bash
# Удаление БД PostgreSQL (drop only, без restore).
# Выполнять из корня каталога ansible: ./scripts/run/run_drop_db.sh <db_name> [--yes] [--check] ...
set -euo pipefail
cd "$(dirname "$0")/../.."

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-registry.example.com/platform/base-images/ansible:1.0}"
PLAYBOOK="playbooks/estate_databases/playbooks/drop_db.yaml"
ASSUME_YES=false

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <db_name> [--yes] [ansible_extra_args...]"
  echo ""
  echo "Examples:"
  echo "  $0 treasury_lp_adapter --yes"
  echo "  $0 treasury_lp_adapter --check"
  exit 1
fi

DB_ARG=$1
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) ASSUME_YES=true; shift ;;
    *) break ;;
  esac
done

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

echo "=== DATABASE DROP (no recreate) ==="
echo "Database: $DB_ARG"
echo "Host: ${PG_HOST}:${PG_PORT}"
echo "Admin: ${PG_ADMIN_USER}"
echo "Playbook: $PLAYBOOK"
echo ""

if [[ "$ASSUME_YES" != true ]]; then
  read -p "Delete database '$DB_ARG' and ALL data? (yes/no): " confirmation
  if [[ "$confirmation" != "yes" ]]; then
    echo "Cancelled."
    exit 0
  fi
fi

ANSIBLE_ARGS=(-i "localhost," "$PLAYBOOK" --extra-vars "db_name=$DB_ARG")
ANSIBLE_ARGS+=("$@")

DOCKER_TTY=()
[[ -t 0 ]] && DOCKER_TTY=(-it)

docker run --rm "${DOCKER_TTY[@]}" \
  -v "$(pwd):/work" -w /work \
  --network host \
  -e ANSIBLE_CONFIG=/work/ansible.cfg \
  "$ANSIBLE_IMAGE" \
  ansible-playbook "${ANSIBLE_ARGS[@]}"

echo "SUCCESS: database '$DB_ARG' dropped."
