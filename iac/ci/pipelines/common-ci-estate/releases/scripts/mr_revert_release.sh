#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release_lib.sh
source "${SCRIPT_DIR}/release_lib.sh"

release_log_header "mr_revert_release"

release_require_token

revert_branch="${REVERT_RELEASE_BRANCH:-}"
if [[ -z "$revert_branch" ]]; then
  echo "ERROR: set REVERT_RELEASE_BRANCH when running pipeline (explicit old release branch)" >&2
  exit 2
fi

if [[ ! "$revert_branch" =~ ^upgrade/shop-app-[0-9.]+-estate-[0-9.]+-(preprod|prod)$ ]]; then
  echo "ERROR: REVERT_RELEASE_BRANCH invalid: ${revert_branch}" >&2
  exit 2
fi

if [[ -n "${RELEASE_CURRENT_BRANCH:-}" && "$revert_branch" == "$RELEASE_CURRENT_BRANCH" ]]; then
  echo "ERROR: REVERT_RELEASE_BRANCH must not equal active RELEASE_CURRENT_BRANCH" >&2
  exit 2
fi

target="${RELEASE_TARGET_BRANCH:-main}"
enc_branch="$(release_urlencode "$revert_branch")"
enc_target="$(release_urlencode "$target")"
gpath="$(release_group_path_encoded)"

mrs="$(release_api GET "/groups/${gpath}/merge_requests?state=merged&source_branch=${enc_branch}&target_branch=${enc_target}&per_page=100&scope=all")"
count="$(echo "$mrs" | jq 'length')"
echo "Merged MRs to revert (branch=${revert_branch}): ${count}"

if [[ "$count" -eq 0 ]]; then
  open_count="$(release_list_open_release_mrs "$revert_branch" | jq 'length')"
  echo ""
  echo "DIAGNOSTIC: branch=${revert_branch} merged_mrs=0 open_mrs=${open_count}"
  if [[ "$open_count" -gt 0 ]]; then
    echo "IDEMPOTENT OK: release was never merged to ${target} (${open_count} MR still open)."
    echo "Nothing to revert. Close open MRs manually or run cutover merge instead."
  else
    echo "IDEMPOTENT OK: no merged or open MRs for this branch (nothing to revert)."
  fi
  exit 0
fi

release_countdown "${RELEASE_MERGE_COUNTDOWN_SEC:-60}"

ok=0
fail=0
idx=0
pause="${RELEASE_MERGE_PAUSE_SEC:-2}"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  idx=$((idx + 1))
  project_id="$(echo "$line" | jq -r '.project_id')"
  iid="$(echo "$line" | jq -r '.iid')"
  project_path="$(echo "$line" | jq -r '.references.full' | sed 's/!.*//')"

  echo "--- [${idx}/${count}] revert ${project_path}!${iid} ---"

  payload="$(jq -n \
    --arg branch "revert-${revert_branch//\//-}" \
    --arg msg "Revert release ${revert_branch} (pipeline ${CI_PIPELINE_ID:-n/a})" \
    '{branch: $branch, commit_message: $msg}')"

  if revert_out="$(release_api POST "/projects/${project_id}/merge_requests/${iid}/revert" -d "$payload" 2>&1)"; then
    rev_iid="$(echo "$revert_out" | jq -r '.iid // empty')"
    echo "OK revert ${project_path}!${iid} -> revert MR !${rev_iid}"
    ok=$((ok + 1))
  else
    echo "FAIL revert ${project_path}!${iid}: ${revert_out}"
    fail=$((fail + 1))
  fi

  if [[ "$idx" -lt "$count" ]]; then
    sleep "$pause"
  fi
done < <(echo "$mrs" | jq -c 'sort_by(.references.full) | .[]')

echo "=== SUMMARY revert ok=${ok} fail=${fail} ==="
[[ "$fail" -eq 0 ]] || exit 1
