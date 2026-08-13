#!/usr/bin/env bash
# Shared logging for snap-pair tooling
SNAP_PAIR_LOG="${SNAP_PAIR_LOG:-/var/log/snap-pair.log}"

snap_log() {
  local tag=$1
  local level=$2
  shift 2
  local msg="$*"
  local line="[$(date -Iseconds)] [$level] $msg"

  mkdir -p "$(dirname "$SNAP_PAIR_LOG")"
  echo "$line" >>"$SNAP_PAIR_LOG"
  logger -t "$tag" -p "user.${level}" "$msg"
}

snap_log_ok() {
  snap_log "$1" info "$2"
}

snap_log_warn() {
  snap_log "$1" warning "$2"
}

snap_log_err() {
  snap_log "$1" err "$2"
}
