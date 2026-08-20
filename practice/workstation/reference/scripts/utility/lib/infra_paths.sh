#!/usr/bin/env bash
# Shared path resolution for a multi-env git tree (PROD/ PREPROD/ plus scripts/).
#
# Overrides: OPS_ROOT, GIT_ENV_ROOT, SCRIPTS_ROOT
#
# Usage:
#   source "$SCRIPT_DIR/../lib/infra_paths.sh"
#   load_infra_paths "$SCRIPT_DIR"

_infra_detect_root_from_script_dir() {
  local script_dir="$1"
  local candidate=""
  if [[ -d "$script_dir/../../../PREPROD" || -d "$script_dir/../../../PROD" ]]; then
    candidate="$(cd "$script_dir/../../.." && pwd)"
  elif [[ -d "$script_dir/../../../../PREPROD" || -d "$script_dir/../../../../PROD" ]]; then
    candidate="$(cd "$script_dir/../../../.." && pwd)"
  fi
  if [[ -n "$candidate" && -d "$candidate/scripts/utility" ]]; then
    OPS_ROOT="$candidate"
  fi
}

load_infra_paths() {
  local script_dir="${1:-}"
  local default_root="${HOME}/git"

  if [[ -z "${OPS_ROOT:-}" && -n "$script_dir" ]]; then
    _infra_detect_root_from_script_dir "$script_dir"
  fi
  OPS_ROOT="${OPS_ROOT:-$default_root}"
  export OPS_ROOT
  export SCRIPTS_ROOT="${SCRIPTS_ROOT:-$OPS_ROOT/scripts}"
  export GIT_ENV_ROOT="${GIT_ENV_ROOT:-$OPS_ROOT}"
}
