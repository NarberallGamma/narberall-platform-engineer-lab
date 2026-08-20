#!/usr/bin/env bash
# Backup and restore /boot (vfat ESP) for snap-pair / snap-pac rollback
set -euo pipefail

# shellcheck source=common.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SNAP_PAIR_LIB:-$SCRIPT_DIR}/common.sh"

TAG=snap-boot-backup
BOOT_BACKUP_ROOT="/var/lib/snap-pair/boot"
KEEP="${SNAP_BOOT_BACKUP_KEEP:-15}"
BOOT_SRC="/boot"

# Packages that typically change contents of /boot
BOOT_CRITICAL_RE='^(linux|linux-[^[:space:]]+|mkinitcpio|systemd-boot|grub|efibootmgr|amd-ucode|intel-ucode|sbctl|dracut|ukify)$'

usage() {
  cat <<'EOF'
Usage:
  snap-boot-backup create-pair <pair_id> <root_num> <home_num> [description]
  snap-boot-backup create-snap-pac <root_pre_num>
  snap-boot-backup restore --pair <pair_id>
  snap-boot-backup restore --root <root_snapshot_num>
  snap-boot-backup list
  snap-boot-backup cleanup
  snap-boot-backup snap-pac-pre   # pacman hook entrypoint (stdin: package names)
EOF
  exit 1
}

ensure_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "ERROR: run as root" >&2
    exit 1
  fi
}

ensure_boot_mounted() {
  if ! mountpoint -q "$BOOT_SRC"; then
    echo "ERROR: $BOOT_SRC is not mounted" >&2
    exit 1
  fi
}

write_manifest() {
  local dest=$1
  local pair=${2:-}
  local root=${3:-}
  local home=${4:-}
  local desc=${5:-}
  local root_pre=${6:-}

  cat >"$dest/manifest.json" <<EOF
{
  "pair": "${pair}",
  "root": ${root:-null},
  "home": ${home:-null},
  "root_pre": ${root_pre:-null},
  "description": $(python -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$desc"),
  "created": "$(date -Iseconds)",
  "source": "$BOOT_SRC"
}
EOF
}

link_root_index() {
  local root_num=$1
  local dest_name=$2
  ln -sfn "$dest_name" "$BOOT_BACKUP_ROOT/by-root-$root_num"
}

link_root_pre_index() {
  local root_pre=$1
  local dest_name=$2
  ln -sfn "$dest_name" "$BOOT_BACKUP_ROOT/by-root-pre-$root_pre"
}

create_backup() {
  local dest_name=$1
  shift
  local dest="$BOOT_BACKUP_ROOT/$dest_name"

  ensure_boot_mounted
  mkdir -p "$dest"
  if rsync -a --delete "$BOOT_SRC/" "$dest/"; then
    write_manifest "$dest" "$@"
    local size
    size=$(du -sh "$dest" | awk '{print $1}')
    snap_log_ok "$TAG" "backup OK name=$dest_name size=$size"
    echo "Boot backup saved: $dest_name ($size)"
  else
    snap_log_err "$TAG" "backup FAILED name=$dest_name"
    return 1
  fi
}

cleanup_old() {
  local -a dirs=()
  local dir count

  mapfile -t dirs < <(find "$BOOT_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name 'by-root-*' ! -name 'by-root-pre-*' -printf '%T@ %f\n' | sort -rn | awk '{print $2}')
  count=0
  for dir in "${dirs[@]}"; do
    count=$((count + 1))
    if (( count > KEEP )); then
      rm -rf "$BOOT_BACKUP_ROOT/$dir"
      find "$BOOT_BACKUP_ROOT" -maxdepth 1 -type l -lname "$dir" -delete 2>/dev/null || true
      snap_log_ok "$TAG" "cleanup removed=$dir"
      echo "Removed old boot backup: $dir"
    fi
  done
}

find_backup_dir() {
  local pair=${1:-}
  local root=${2:-}
  local path

  if [[ -n "$pair" && -d "$BOOT_BACKUP_ROOT/$pair" ]]; then
    echo "$BOOT_BACKUP_ROOT/$pair"
    return 0
  fi

  if [[ -n "$root" ]]; then
    for path in \
      "$BOOT_BACKUP_ROOT/by-root-$root" \
      "$BOOT_BACKUP_ROOT/by-root-pre-$root"; do
      if [[ -L "$path" || -d "$path" ]]; then
        readlink -f "$path"
        return 0
      fi
    done

    path=$(snapper -c root list 2>/dev/null | awk -F'│' -v n="$root" '
      $1 ~ "^[ \t]*" n "[ \t]*$" && index($0, "pair=") {
        match($0, /pair=[0-9_]+/)
        if (RSTART > 0) {
          pair=substr($0, RSTART + 5, RLENGTH - 5)
          print pair
        }
        exit
      }')
    if [[ -n "$path" && -d "$BOOT_BACKUP_ROOT/$path" ]]; then
      echo "$BOOT_BACKUP_ROOT/$path"
      return 0
    fi
  fi

  return 1
}

restore_backup() {
  local backup_dir=$1

  if [[ ! -d "$backup_dir" ]]; then
    echo "ERROR: boot backup not found: $backup_dir" >&2
    exit 1
  fi

  ensure_boot_mounted
  local name
  name=$(basename "$backup_dir")
  echo "Restoring /boot from $name..."
  if rsync -a --delete "$backup_dir/" "$BOOT_SRC/"; then
    snap_log_ok "$TAG" "restore OK from=$name"
    echo "Boot restored."
  else
    snap_log_err "$TAG" "restore FAILED from=$name"
    return 1
  fi
}

boot_critical_transaction() {
  local pkg
  while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    if [[ "$pkg" =~ $BOOT_CRITICAL_RE ]]; then
      return 0
    fi
  done
  return 1
}

cmd_create_pair() {
  local pair=$1 root=$2 home=$3 desc=${4:-manual}
  create_backup "$pair" "$pair" "$root" "$home" "$desc" ""
  link_root_index "$root" "$pair"
  cleanup_old
}

cmd_create_snap_pac() {
  local root_pre=$1
  create_backup "root-pre-$root_pre" "" "" "" "snap-pac pre #$root_pre" "$root_pre"
  link_root_pre_index "$root_pre" "root-pre-$root_pre"
  cleanup_old
}

cmd_snap_pac_pre() {
  local root_pre

  if ! boot_critical_transaction; then
    snap_log_ok "$TAG" "snap-pac-pre SKIP (no boot-critical packages)"
    exit 0
  fi

  if [[ ! -f /tmp/snap-pac-pre_root ]]; then
    snap_log_warn "$TAG" "snap-pac-pre SKIP (missing /tmp/snap-pac-pre_root)"
    echo "WARN: snap-pac root pre file missing, skipping boot backup" >&2
    exit 0
  fi

  root_pre=$(tr -d '\n' </tmp/snap-pac-pre_root)
  if [[ -z "$root_pre" ]]; then
    snap_log_warn "$TAG" "snap-pac-pre SKIP (empty root pre number)"
    echo "WARN: empty snap-pac root pre number, skipping boot backup" >&2
    exit 0
  fi

  snap_log_ok "$TAG" "snap-pac-pre START root-pre=#$root_pre"
  cmd_create_snap_pac "$root_pre"
}

cmd_list() {
  local dir
  for dir in "$BOOT_BACKUP_ROOT"/*; do
    [[ -d "$dir" ]] || continue
    [[ "$(basename "$dir")" == by-root-* ]] && continue
    [[ -f "$dir/manifest.json" ]] && echo "$(basename "$dir")  $(cat "$dir/manifest.json")"
  done
}

main() {
  ensure_root
  mkdir -p "$BOOT_BACKUP_ROOT"

  case "${1:-}" in
    create-pair)
      [[ $# -ge 4 ]] || usage
      cmd_create_pair "$2" "$3" "$4" "${5:-manual}"
      ;;
    create-snap-pac)
      [[ $# -eq 2 ]] || usage
      cmd_create_snap_pac "$2"
      ;;
    snap-pac-pre)
      cmd_snap_pac_pre
      ;;
    restore)
      case "${2:-}" in
        --pair)
          [[ $# -eq 3 ]] || usage
          restore_backup "$(find_backup_dir "$3" "")"
          ;;
        --root)
          [[ $# -eq 3 ]] || usage
          if ! restore_dir=$(find_backup_dir "" "$3"); then
            snap_log_warn "$TAG" "restore SKIP no backup for root=#$3"
            echo "WARN: no boot backup for root #$3; root/home still restored" >&2
            return 1
          fi
          restore_backup "$restore_dir"
          ;;
        *) usage ;;
      esac
      ;;
    list)
      cmd_list
      ;;
    cleanup)
      cleanup_old
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"
