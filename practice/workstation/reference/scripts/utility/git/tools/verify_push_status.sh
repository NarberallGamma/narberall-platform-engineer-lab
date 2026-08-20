#!/usr/bin/env bash
# Verify git repos: clean working tree, expected commit message, nothing ahead of origin.
#
# Usage:
#   verify_push_status.sh --env PREPROD --repo kafka --repo web-service
#   verify_push_status.sh --env PREPROD --all-changed --message "commit msg"
#   verify_push_status.sh --env PREPROD --all-changed
#   verify_push_status.sh --path /path/to/repo --branch main
#
# Options:
#   --env PREPROD|PROD       Base directory CR/<env>/
#   --repo NAME              Repo under --env (repeatable)
#   --all-changed            All git repos under --env (not only dirty)
#   --all-repos              Alias for --all-changed
#   --path DIR               Single repo path (repeatable)
#   --message TEXT           Require HEAD commit subject to match exactly
#   --branch NAME            Expected branch (default: current)
#   --quiet                  Only print failures and summary
#   -h, --help               Show help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/infra_paths.sh
source "$SCRIPT_DIR/../../lib/infra_paths.sh"
load_infra_paths "$SCRIPT_DIR"
DEFAULT_CR_ROOT="$GIT_ENV_ROOT"

ENV=""
BASE_PATH=""
PATHS=()
REPOS=()
ALL_REPOS=false
MESSAGE=""
BRANCH=""
QUIET=false

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

log() { [[ "$QUIET" == true ]] || echo "[verify_push] $*"; }
err() { echo "[verify_push] FAIL: $*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    --path) PATHS+=("$2"); shift 2 ;;
    --repo) REPOS+=("$2"); shift 2 ;;
    --all-changed|--all-repos) ALL_REPOS=true; shift ;;
    --message) MESSAGE="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --quiet) QUIET=true; shift ;;
    -h|--help) usage 0 ;;
    *) err "Unknown argument: $1"; usage 1 ;;
  esac
done

if [[ -n "$ENV" ]]; then
  [[ "$ENV" == "PREPROD" || "$ENV" == "PROD" ]] || { err "--env must be PREPROD or PROD"; exit 1; }
  BASE_PATH="$DEFAULT_CR_ROOT/$ENV"
fi

resolve_targets() {
  local targets=()
  if [[ ${#PATHS[@]} -gt 0 ]]; then
    targets+=("${PATHS[@]}")
  elif [[ -n "$BASE_PATH" ]]; then
    if [[ ${#REPOS[@]} -gt 0 ]]; then
      local r
      for r in "${REPOS[@]}"; do
        targets+=("$BASE_PATH/$r")
      done
    elif [[ "$ALL_REPOS" == true ]]; then
      local g d
      for g in "$BASE_PATH"/*/.git; do
        [[ -d "$g" ]] || continue
        targets+=("$(dirname "$g")")
      done
    else
      err "Specify --repo, --all-changed, or --path"
      exit 1
    fi
  else
    err "Specify --env or --path"
    exit 1
  fi
  printf '%s\n' "${targets[@]}"
}

check_repo() {
  local repo_path="$1"
  local name
  name="$(basename "$repo_path")"

  if [[ ! -d "$repo_path/.git" ]]; then
    err "$name: not a git repository"
    return 1
  fi

  local branch current_branch ahead dirty last
  current_branch="$(git -C "$repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  branch="${BRANCH:-$current_branch}"

  if [[ "$current_branch" != "$branch" ]]; then
    err "$name: on branch $current_branch, expected $branch"
    return 1
  fi

  if [[ -n "$(git -C "$repo_path" status --porcelain 2>/dev/null || true)" ]]; then
    err "$name: working tree dirty"
    return 1
  fi

  ahead="$(git -C "$repo_path" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo "?")"
  if [[ "$ahead" == "?" ]]; then
    err "$name: no upstream tracking branch"
    return 1
  fi
  if [[ "$ahead" != "0" ]]; then
    err "$name: $ahead commit(s) ahead of origin (not pushed)"
    return 1
  fi

  if [[ -n "$MESSAGE" ]]; then
    last="$(git -C "$repo_path" log -1 --format=%s 2>/dev/null || echo "")"
    if [[ "$last" != "$MESSAGE" ]]; then
      err "$name: last commit subject mismatch (got: $last)"
      return 1
    fi
  fi

  log "OK: $name ($branch, synced)"
  return 0
}

main() {
  local targets=()
  mapfile -t targets < <(resolve_targets || true)

  if [[ ${#targets[@]} -eq 0 ]]; then
    log "No repositories to verify."
    exit 0
  fi

  local ok=0 fail=0 t
  for t in "${targets[@]}"; do
    if check_repo "$t"; then
      ((ok++)) || true
    else
      ((fail++)) || true
    fi
  done

  echo "[verify_push] Summary: ok=$ok fail=$fail total=${#targets[@]}"
  [[ "$fail" -eq 0 ]]
}

main
