#!/usr/bin/env bash
# Commit и push git-репозиториев estate (PREPROD/PROD).
# Транспорт: --transport auto|https|ssh (PAT в ~/.config/ops/.env-cloud, см. README).
# Документация: scripts/utility/git/README.md
#
# Usage:
#   git_commit_push.sh --env PREPROD --message "commit msg" --branch main
#   git_commit_push.sh --env PREPROD --message "commit msg" --repo kafka
#   git_commit_push.sh --env PREPROD --message "commit msg" --repo kafka --repo common-ci
#   git_commit_push.sh --path /path/to/repo --message "commit msg" --branch main
#   git_commit_push.sh --env PREPROD --message "msg" --all-changed
#   git_commit_push.sh --env PREPROD --message "msg" --dry-run --all-changed
#
# Options:
#   --env PREPROD|PROD     Base directory: .../CR/<env>/
#   --path DIR             Single repo path (overrides --env/--repo)
#   --repo NAME            Repo name under --env (repeatable)
#   --all-changed          All git repos under --env with uncommitted changes
#   --message TEXT         Commit message (required unless --push-only)
#   --branch NAME          Branch to commit/push (default: current branch)
#   --push-only            Skip commit, only push existing commits
#   --pause-seconds N      Pause between repos after push (default: 0; use if sshd limits not raised)
#   --push-retries N       Retries per repo on push failure (default: 2)
#   --retry-delay N        Seconds before push retry (default: 5)
#   --verify               After batch, run verify_push_status.sh on same targets
#   --dry-run              Print actions without git write/push
#   --no-verify            Pass --no-verify to git commit (use sparingly)
#   --transport MODE       auto|https|ssh (default: auto; https uses PAT from ~/.config/ops/.env-cloud)
#   -h, --help             Show help

set -euo pipefail

# Без интерактивных credential GUI (GCM / ssh askpass). PAT через GIT_ASKPASS в HTTPS-режиме.
export GIT_TERMINAL_PROMPT=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/tools/verify_push_status.sh"
# shellcheck source=../lib/infra_paths.sh
source "$SCRIPT_DIR/../lib/infra_paths.sh"
load_infra_paths "$SCRIPT_DIR"
DEFAULT_CR_ROOT="$GIT_ENV_ROOT"

ENV=""
BASE_PATH=""
PATHS=()
REPOS=()
ALL_CHANGED=false
MESSAGE=""
BRANCH=""
PUSH_ONLY=false
DRY_RUN=false
NO_VERIFY=false
RUN_VERIFY=false
PAUSE_SECONDS=0
PUSH_RETRIES=2
RETRY_DELAY=5
TRANSPORT=auto

GIT_LIB="$SCRIPT_DIR/lib"
# shellcheck source=lib/load_git_env.sh
source "$GIT_LIB/load_git_env.sh" 2>/dev/null || true
# shellcheck source=lib/git_https.sh
source "$GIT_LIB/git_https.sh" 2>/dev/null || true

usage() {
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

log() { echo "[git_commit_push] $*"; }
err() { echo "[git_commit_push] ERROR: $*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    --path) PATHS+=("$2"); shift 2 ;;
    --repo) REPOS+=("$2"); shift 2 ;;
    --all-changed) ALL_CHANGED=true; shift ;;
    --message) MESSAGE="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --push-only) PUSH_ONLY=true; shift ;;
    --pause-seconds) PAUSE_SECONDS="$2"; shift 2 ;;
    --push-retries) PUSH_RETRIES="$2"; shift 2 ;;
    --retry-delay) RETRY_DELAY="$2"; shift 2 ;;
    --verify) RUN_VERIFY=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --no-verify) NO_VERIFY=true; shift ;;
    --transport) TRANSPORT="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) err "Unknown argument: $1"; usage 1 ;;
  esac
done

if [[ -n "$ENV" ]]; then
  if [[ "$ENV" != "PREPROD" && "$ENV" != "PROD" ]]; then
    err "--env must be PREPROD or PROD"
    exit 1
  fi
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
    elif [[ "$ALL_CHANGED" == true ]]; then
      local d g
      for g in "$BASE_PATH"/*/.git; do
        [[ -d "$g" ]] || continue
        d="$(dirname "$g")"
        if [[ -n "$(git -C "$d" status --porcelain 2>/dev/null || true)" ]]; then
          targets+=("$d")
        fi
      done
    else
      err "Specify --repo, --all-changed, or --path"
      exit 1
    fi
  else
    err "Specify --env or --path"
    exit 1
  fi

  if [[ ${#targets[@]} -eq 0 ]]; then
    return 0
  fi

  printf '%s\n' "${targets[@]}"
}

repo_git_env() {
  local repo_path="$1"
  case "$repo_path" in
    */PREPROD/*) printf 'PREPROD' ;;
    */PROD/*) printf 'PROD' ;;
    *)
      if [[ -n "${ENV:-}" ]]; then
        printf '%s' "$ENV"
      else
        return 1
      fi
      ;;
  esac
}

resolve_transport() {
  local repo_env="$1"
  case "$TRANSPORT" in
    ssh) printf 'ssh' ;;
    https) printf 'https' ;;
    auto)
      if [[ -n "$(gitlab_token_for_env "$repo_env" 2>/dev/null || true)" ]]; then
        printf 'https'
      else
        printf 'ssh'
      fi
      ;;
    *)
      err "--transport must be auto, https, or ssh"
      exit 1
      ;;
  esac
}

with_repo_git_transport() {
  local repo_path="$1"
  local mode="$2"
  shift 2
  if [[ "$mode" == "https" ]]; then
    unset GIT_SSH_COMMAND 2>/dev/null || true
    local repo_env
    repo_env="$(repo_git_env "$repo_path")" || {
      err "$(basename "$repo_path"): cannot detect PREPROD/PROD for HTTPS"
      return 1
    }
    if ! git_https_prepare_auth "$repo_env"; then
      return 1
    fi
    ensure_origin_https_sanitized "$repo_path" || true
    local rc=0
    "$@" || rc=$?
    git_https_cleanup_askpass
    return "$rc"
  fi
  # SSH: WSL native ssh (не Windows ssh.exe — иначе GUI passphrase / GCM)
  if [[ -z "${GIT_SSH_COMMAND:-}" ]]; then
    export GIT_SSH_COMMAND="ssh"
  fi
  "$@"
}

do_push() {
  local repo_path="$1"
  local target_branch="$2"
  local repo_env mode
  repo_env="$(repo_git_env "$repo_path")" || repo_env="${ENV:-}"
  mode="$(resolve_transport "$repo_env")"
  local attempt=1

  while [[ "$attempt" -le "$PUSH_RETRIES" ]]; do
    if [[ "$attempt" -gt 1 ]]; then
      log "$(basename "$repo_path"): push retry $attempt/$PUSH_RETRIES (wait ${RETRY_DELAY}s)"
      sleep "$RETRY_DELAY"
    fi
    if with_repo_git_transport "$repo_path" "$mode" \
      git -C "$repo_path" push -u origin "$target_branch"; then
      return 0
    fi
    ((attempt++)) || true
  done
  return 1
}

process_repo() {
  local repo_path="$1"
  local name
  name="$(basename "$repo_path")"

  if [[ ! -d "$repo_path/.git" ]]; then
    err "$name: not a git repository ($repo_path)"
    return 1
  fi

  local repo_env mode
  repo_env="$(repo_git_env "$repo_path")" || repo_env="${ENV:-}"
  mode="$(resolve_transport "$repo_env")"
  log "=== $name ($repo_path) transport=$mode ==="

  local current_branch
  current_branch="$(git -C "$repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  local target_branch="${BRANCH:-$current_branch}"

  if [[ -z "$target_branch" || "$target_branch" == "HEAD" ]]; then
    err "$name: detached HEAD, specify --branch"
    return 1
  fi

  if [[ "$target_branch" != "$current_branch" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      log "$name: would checkout $target_branch"
    else
      with_repo_git_transport "$repo_path" "$mode" \
        git -C "$repo_path" checkout "$target_branch"
    fi
  fi

  local status
  status="$(git -C "$repo_path" status --porcelain 2>/dev/null || true)"

  if [[ "$PUSH_ONLY" != true ]]; then
    if [[ -z "$MESSAGE" ]]; then
      err "$name: --message is required (unless --push-only)"
      return 1
    fi
    if [[ -n "$status" ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        log "$name: would git add -A and commit"
        git -C "$repo_path" status --short | sed 's/^/  /'
      else
        with_repo_git_transport "$repo_path" "$mode" git -C "$repo_path" add -A
        local commit_args=(-m "$MESSAGE")
        [[ "$NO_VERIFY" == true ]] && commit_args+=(--no-verify)
        with_repo_git_transport "$repo_path" "$mode" \
          git -C "$repo_path" commit "${commit_args[@]}"
        log "$name: committed on $target_branch"
      fi
    else
      log "$name: no changes to commit"
    fi
  fi

  local ahead=0
  ahead="$(git -C "$repo_path" rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo 0)"
  if [[ "$ahead" == "0" && -z "$status" && "$PUSH_ONLY" != true ]]; then
    log "$name: nothing to push"
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log "$name: would push to origin $target_branch (pause ${PAUSE_SECONDS}s after)"
    return 0
  fi

  if do_push "$repo_path" "$target_branch"; then
    log "$name: pushed to origin/$target_branch"
    return 0
  fi
  err "$name: push failed after $PUSH_RETRIES attempt(s)"
  return 1
}

run_verify() {
  local targets=("$@")
  [[ ${#targets[@]} -gt 0 ]] || return 0
  [[ -x "$VERIFY_SCRIPT" ]] || { err "verify script not found: $VERIFY_SCRIPT"; return 1; }

  log "Running post-push verification..."
  local args=()
  if [[ -n "$ENV" ]]; then
    args+=(--env "$ENV")
  fi
  local t name
  for t in "${targets[@]}"; do
    args+=(--path "$t")
  done
  [[ -n "$BRANCH" ]] && args+=(--branch "$BRANCH")
  if [[ "$PUSH_ONLY" != true && -n "$MESSAGE" ]]; then
    args+=(--message "$MESSAGE")
  fi
  bash "$VERIFY_SCRIPT" "${args[@]}"
}

main() {
  local targets=()
  mapfile -t targets < <(resolve_targets || true)

  if [[ ${#targets[@]} -eq 0 ]]; then
    log "No repositories to process."
    exit 0
  fi

  log "Repos: ${#targets[@]}, pause=${PAUSE_SECONDS}s, push_retries=$PUSH_RETRIES"

  local ok=0 fail=0
  local i=0 total=${#targets[@]}
  local t
  for t in "${targets[@]}"; do
    ((i++)) || true
    if process_repo "$t"; then
      ((ok++)) || true
    else
      ((fail++)) || true
    fi
    if [[ "$DRY_RUN" != true && "$i" -lt "$total" && "$PAUSE_SECONDS" -gt 0 ]]; then
      sleep "$PAUSE_SECONDS"
    fi
    echo ""
  done

  log "Done: ok=$ok fail=$fail total=$total"

  if [[ "$RUN_VERIFY" == true && "$DRY_RUN" != true ]]; then
    echo ""
    if ! run_verify "${targets[@]}"; then
      ((fail++)) || true
      log "Verification failed"
      exit 1
    fi
  fi

  [[ "$fail" -eq 0 ]]
}

main
