#!/usr/bin/env bash
# Create paired root+home snapshots with matching pair ID and /boot backup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# On a real host: /usr/local/lib/snap-pair/common.sh
# shellcheck source=common.sh
source "${SNAP_PAIR_LIB:-$SCRIPT_DIR}/common.sh"

TAG=snap-pair
desc="${1:-manual}"
pair=$(date +%Y%m%d_%H%M%S)

snap_log_ok "$TAG" "START create pair=$pair desc=$desc"

root_num=$(snapper --no-dbus -c root create \
  --description "$desc" \
  --userdata "pair=$pair" \
  --print-number)
snap_log_ok "$TAG" "root snapshot #$root_num created (pair=$pair)"

home_num=$(snapper --no-dbus -c home create \
  --description "$desc" \
  --userdata "pair=$pair" \
  --print-number)
snap_log_ok "$TAG" "home snapshot #$home_num created (pair=$pair)"

BOOT_BACKUP="${SCRIPT_DIR}/snap-boot-backup.example.sh"
if "$BOOT_BACKUP" create-pair "$pair" "$root_num" "$home_num" "$desc"; then
  snap_log_ok "$TAG" "boot backup OK pair=$pair path=/var/lib/snap-pair/boot/$pair"
else
  snap_log_err "$TAG" "boot backup FAILED pair=$pair (root #$root_num home #$home_num exist)"
  exit 1
fi

snap_log_ok "$TAG" "DONE pair=$pair root=#$root_num home=#$home_num boot=OK"

echo "Paired snapshot created:"
echo "  pair=$pair"
echo "  root #$root_num"
echo "  home #$home_num"
echo "  boot backup: /var/lib/snap-pair/boot/$pair"
echo "  log: $SNAP_PAIR_LOG"
