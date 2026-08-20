#!/usr/bin/env bash
# Normalize git working trees under estate CR: drop EOL-only phantom diffs (CRLF/LF),
# keep files with real content changes.
#
# Use BEFORE commit / push on Windows checkout (NTFS + Cursor).
# Does NOT strip CRLF on disk blindly; uses git restore to match HEAD (LF or CRLF as committed).
#
# Why not fix_crlf_cr_tree.sh: blind CRLF strip breaks repos where HEAD already has CRLF.
#
# Usage:
#   normalize_worktree_before_dirty_check.sh [--env PROD|PREPROD|ALL] [--repo NAME ...] [--dry-run] [--verbose]
#
# Default without --repo: --env ALL (every git repo under PROD/ and PREPROD/).
# With --repo: only named repos; --env PROD or PREPROD required (not ALL).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/infra_paths.sh
source "$SCRIPT_DIR/../../lib/infra_paths.sh"
load_infra_paths "$SCRIPT_DIR"
CR_ROOT="$GIT_ENV_ROOT"

ENV_SCOPE="ALL"
REPOS=()
DRY_RUN=0
VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_SCOPE="${2^^}"; shift 2 ;;
    --repo) REPOS+=("$2"); shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --verbose|-v) VERBOSE=1; shift ;;
    -h|--help)
      sed -n '2,21p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

roots=()
target_repos=()

if [[ ${#REPOS[@]} -gt 0 ]]; then
  if [[ "$ENV_SCOPE" == "ALL" ]]; then
    echo "With --repo specify --env PROD or PREPROD (not ALL)" >&2
    exit 1
  fi
  case "$ENV_SCOPE" in
    PROD|PREPROD) ;;
    *) echo "Invalid --env: $ENV_SCOPE (PROD or PREPROD with --repo)" >&2; exit 1 ;;
  esac
  for r in "${REPOS[@]}"; do
    target_repos+=("$CR_ROOT/$ENV_SCOPE/$r")
  done
else
  case "$ENV_SCOPE" in
    PROD) roots+=("$CR_ROOT/PROD") ;;
    PREPROD) roots+=("$CR_ROOT/PREPROD") ;;
    ALL) roots+=("$CR_ROOT/PROD" "$CR_ROOT/PREPROD") ;;
    *) echo "Invalid --env: $ENV_SCOPE (PROD, PREPROD, ALL)" >&2; exit 1 ;;
  esac
fi

total_repos=0
repos_with_phantom=0
total_restored=0
total_kept=0

restore_repo() {
  local repo="$1"
  local name restored=0 kept=0
  local porcelain diff_out real_out

  [[ -d "$repo/.git" ]] || return 0
  ((total_repos++)) || true
  name="$(basename "$repo")"
  local env_name
  env_name="$(basename "$(dirname "$repo")")"

  porcelain="$(git -C "$repo" status --porcelain 2>/dev/null || true)"
  if [[ -z "$porcelain" ]]; then
    [[ "$VERBOSE" -eq 1 ]] && echo "$env_name/$name: clean"
    return 0
  fi

  diff_out="$(git -C "$repo" diff 2>/dev/null || true)"
  if [[ -z "$diff_out" ]] && [[ -z "$(git -C "$repo" diff --cached 2>/dev/null || true)" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "$env_name/$name: [dry-run] stat-only phantom, would git restore ."
    else
      git -C "$repo" restore . 2>/dev/null || true
      ((repos_with_phantom++)) || true
      echo "$env_name/$name: stat-only phantom cleared (git restore .)"
    fi
    return 0
  fi

  mapfile -t all_dirty < <(git -C "$repo" diff --name-only 2>/dev/null | sort -u)
  mapfile -t real_dirty < <(git -C "$repo" diff --ignore-space-at-eol --name-only 2>/dev/null | sort -u)
  kept=${#real_dirty[@]}

  if [[ ${#all_dirty[@]} -eq 0 ]]; then
    if [[ "$kept" -gt 0 ]]; then
      echo "$env_name/$name: only real changes ($kept files)"
    fi
    total_kept=$((total_kept + kept))
    return 0
  fi

  local phantom_files=()
  if [[ ${#real_dirty[@]} -eq 0 ]]; then
    phantom_files=("${all_dirty[@]}")
  else
    mapfile -t phantom_files < <(comm -23 \
      <(printf '%s\n' "${all_dirty[@]}") \
      <(printf '%s\n' "${real_dirty[@]}"))
  fi

  restored=${#phantom_files[@]}
  if [[ "$restored" -gt 0 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      [[ "$VERBOSE" -eq 1 ]] && printf '  [dry-run] %s/%s: restore %s\n' "$env_name" "$name" "${phantom_files[*]}"
    else
      git -C "$repo" restore -- "${phantom_files[@]}" 2>/dev/null || true
      [[ "$VERBOSE" -eq 1 ]] && printf '  restored %s/%s: %s\n' "$env_name" "$name" "${phantom_files[*]}"
    fi
    ((repos_with_phantom++)) || true
    echo "$env_name/$name: restored_phantom=$restored kept_real=$kept"
  elif [[ "$kept" -gt 0 ]]; then
    echo "$env_name/$name: only real changes ($kept files)"
  fi

  total_restored=$((total_restored + restored))
  total_kept=$((total_kept + kept))
}

if [[ ${#target_repos[@]} -gt 0 ]]; then
  echo "normalize_worktree: env=$ENV_SCOPE repos=${REPOS[*]} dry_run=$DRY_RUN cr_root=$CR_ROOT"
else
  echo "normalize_worktree: env=$ENV_SCOPE dry_run=$DRY_RUN cr_root=$CR_ROOT"
fi
echo

if [[ ${#target_repos[@]} -gt 0 ]]; then
  for repo in "${target_repos[@]}"; do
    restore_repo "$repo"
  done
else
  for root in "${roots[@]}"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r -d '' repo; do
      restore_repo "$repo"
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
  done
fi

echo
echo "Done: repos_scanned=$total_repos repos_with_phantom=$repos_with_phantom restored_files=$total_restored kept_real_files=$total_kept"
