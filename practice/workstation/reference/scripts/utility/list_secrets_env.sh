#!/usr/bin/env bash
# Canonical WSL secrets inventory under ~/scripts/.env-* (keys only, no values in list/verify).
# Deploy: ~/scripts/utility/list_secrets_env.sh
set -euo pipefail

SCRIPT_NAME="${0##*/}"

declare -A ALIASES=(
  [global]="${HOME}/.config/ops/.env-lab"
  [lab]="${HOME}/.config/ops/.env-lab"
  [estate]="${HOME}/.config/ops/.env-cloud"
  [cr]="${HOME}/.config/ops/.env-cloud"
  [edge]="${HOME}/.config/ops/.env-edge"
  [cloud]="${HOME}/.config/ops/.env-cloud"
  [vault]="${HOME}/.config/ops/.env-vault"
)

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <action> [args]

Actions:
  list [alias]     List all .env-* under ~/scripts (or one alias); keys only
  paths            alias=path table
  path <alias>     Print canonical path for source
  verify [alias]   key=ok|empty per file (no values)
  source-cmd <alias>  Print: set -a; source <path>; set +a
  with-env <alias> -- <command...>  Run command with env sourced

Aliases: global, lab, estate|cr, edge, cloud, vault

Note: legacy symlinks ~/scripts/*/.env point to .env-* for old scripts.
EOF
}

resolve_alias() {
  local a="${1,,}"
  local p="${ALIASES[$a]:-}"
  if [[ -z "$p" ]]; then
    echo "ERROR: unknown alias '$1' (use: ${!ALIASES[*]})" >&2
    return 1
  fi
  printf '%s' "$p"
}

list_keys() {
  local f="$1"
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$f" 2>/dev/null | cut -d= -f1 | sort -u || true
}

key_nonempty() {
  local f="$1" key="$2"
  local line value
  line="$(grep -E "^${key}=" "$f" 2>/dev/null | tail -1 || true)"
  [[ -z "$line" ]] && return 1
  value="${line#*=}"
  value="${value%$'\r'}"
  [[ -n "$value" ]]
}

action_list() {
  local only="${1:-}"
  if [[ -n "$only" ]]; then
    local f
    f="$(resolve_alias "$only")"
    echo "=== $only -> $f ==="
    if [[ ! -f "$f" ]]; then
      echo "MISSING"
      return 0
    fi
    echo "size_bytes=$(wc -c <"$f" | tr -d ' ')"
    list_keys "$f"
    return 0
  fi

  while IFS= read -r f; do
    echo "=== $f ==="
    if [[ ! -f "$f" ]]; then
      echo "MISSING"
      echo
      continue
    fi
    echo "size_bytes=$(wc -c <"$f" | tr -d ' ')"
    list_keys "$f"
    echo
  done < <(find "$HOME/scripts" -maxdepth 3 \( -name '.env-*' -o -name 'env.example' \) 2>/dev/null | sort)
}

action_paths() {
  for a in global lab estate edge cloud vault; do
    [[ -n "${ALIASES[$a]:-}" ]] || continue
    printf '%s=%s\n' "$a" "${ALIASES[$a]}"
  done
  echo "cr=${ALIASES[cr]}"
}

action_verify() {
  local only="${1:-}"
  local files=()
  if [[ -n "$only" ]]; then
    files=("$(resolve_alias "$only")")
  else
    for a in global lab estate edge cloud vault; do
      files+=("${ALIASES[$a]}")
    done
  fi
  local f key
  for f in "${files[@]}"; do
    echo "=== $f ==="
    if [[ ! -f "$f" ]]; then
      echo "MISSING"
      echo
      continue
    fi
    while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      if key_nonempty "$f" "$key"; then
        echo "${key}=ok"
      else
        echo "${key}=empty"
      fi
    done < <(list_keys "$f")
    echo
  done
}

action_with_env() {
  local alias="$1"
  shift
  if [[ "${1:-}" != "--" ]]; then
    echo "ERROR: use: with-env <alias> -- <command>" >&2
    return 1
  fi
  shift
  if [[ $# -eq 0 ]]; then
    echo "ERROR: command required after --" >&2
    return 1
  fi
  local f
  f="$(resolve_alias "$alias")"
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing $f" >&2
    return 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "$f"
  set +a
  exec bash -c "$*"
}

main() {
  local action="${1:-list}"
  shift || true
  case "$action" in
    list) action_list "${1:-}" ;;
    paths) action_paths ;;
    path)
      [[ -n "${1:-}" ]] || { usage >&2; exit 1; }
      resolve_alias "$1"
      ;;
    verify) action_verify "${1:-}" ;;
    source-cmd)
      [[ -n "${1:-}" ]] || { usage >&2; exit 1; }
      local f
      f="$(resolve_alias "$1")"
      echo "set -a; source \"$f\"; set +a"
      ;;
    with-env) action_with_env "$@" ;;
    -h|--help|help) usage ;;
    *)
      echo "ERROR: unknown action '$action'" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
