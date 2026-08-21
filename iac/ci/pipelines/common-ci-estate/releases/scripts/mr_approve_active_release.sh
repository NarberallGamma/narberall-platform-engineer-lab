#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release_lib.sh
source "${SCRIPT_DIR}/release_lib.sh"

release_log_header "mr_approve_active_release"

release_require_current_branch
release_require_token

branch="$RELEASE_CURRENT_BRANCH"
mrs="$(release_list_open_release_mrs "$branch")"
count="$(echo "$mrs" | jq 'length')"
merged_count="$(release_list_merged_release_mrs "$branch" | jq 'length')"

echo "Open MRs to approve: ${count} (branch=${branch})"
echo "Merged MRs (reference): ${merged_count}"

if [[ "$count" -eq 0 ]]; then
  release_print_release_state "$branch"
  approve_env="${CI_PROJECT_DIR:-.}/release_approve.env"
  : >"$approve_env"
  if [[ "$merged_count" -gt 0 ]]; then
    echo ""
    echo "IDEMPOTENT OK: no open MRs; ${merged_count} already merged to ${RELEASE_TARGET_BRANCH:-main}."
    echo "Approve step not required (release likely already cut over)."
    {
      echo "RELEASE_APPROVED=1"
      echo "APPROVED_BY=${GITLAB_USER_LOGIN:-ci}"
      echo "APPROVED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "RELEASE_BRANCH=${branch}"
      echo "RELEASE_APPROVE_PIPELINE_ID=${CI_PIPELINE_ID:-0}"
      echo "RELEASE_APPROVE_OK=0"
      echo "RELEASE_APPROVE_SKIP=${merged_count}"
      echo "RELEASE_APPROVE_FAIL=0"
      echo "RELEASE_APPROVE_IDEMPOTENT=already_merged"
    } >>"$approve_env"
    echo "=== SUMMARY approve ok=0 skip=${merged_count} fail=0 (idempotent) ==="
    exit 0
  fi
  echo ""
  echo "ERROR: no open or merged MRs for branch '${branch}'." >&2
  echo "Cause: upgrade branch not pushed, MRs not created, or RELEASE_CURRENT_BRANCH is wrong." >&2
  echo "Fix: push upgrade branch to helm repos, or set RELEASE_BRANCH when running pipeline." >&2
  exit 1
fi

ok=0
skip=0
fail=0
approve_env="${CI_PROJECT_DIR:-.}/release_approve.env"
idx=0

: >"$approve_env"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  idx=$((idx + 1))
  project_id="$(echo "$line" | jq -r '.project_id')"
  iid="$(echo "$line" | jq -r '.iid')"
  source_branch="$(echo "$line" | jq -r '.source_branch')"
  sha="$(echo "$line" | jq -r '.sha')"
  project_path="$(echo "$line" | jq -r '.references.full' | sed 's/!.*//')"

  echo ""
  echo "--- [${idx}/${count}] approve ${project_path}!${iid} ---"
  release_assert_branch_is_current "$source_branch"

  if release_mr_is_draft "$project_id" "$iid"; then
    echo "SKIP approve ${project_path}!${iid} (draft MR; mark as ready in GitLab or set RELEASE_UNDRAFT_DRAFT_MRS=1)"
    skip=$((skip + 1))
    continue
  fi

  if release_mr_is_approved "$project_id" "$iid"; then
    echo "SKIP approve ${project_path}!${iid} (already approved, idempotent)"
    skip=$((skip + 1))
    continue
  fi

  if ! release_wait_for_mr_ready "$project_id" "$iid"; then
    echo "FAIL approve ${project_path}!${iid}: MR not ready for approve (see wait_ready log above)" >&2
    fail=$((fail + 1))
    continue
  fi

  tmp="$(mktemp)"
  http_code="$(release_api_http POST "/projects/${project_id}/merge_requests/${iid}/approve?sha=$(release_urlencode "$sha")" "$tmp" -d '{}')"
  body="$(cat "$tmp")"
  rm -f "$tmp"

  if release_http_is_success "$http_code"; then
    echo "OK approve ${project_path}!${iid}"
    ok=$((ok + 1))
    comment="Release approval via common-ci \`release-02-approve-all-mrs\`.

- Pipeline: ${CI_PIPELINE_URL:-n/a}
- Triggered by: @${GITLAB_USER_LOGIN:-unknown} (${GITLAB_USER_NAME:-})
- Active branch: \`${branch}\`
- Bot approve: release-bot (API token)"
    release_mr_comment "$project_id" "$iid" "$comment" || true
  elif release_http_body_indicates_already_approved "$body"; then
    echo "SKIP approve ${project_path}!${iid} (API: already approved, idempotent)"
    skip=$((skip + 1))
  else
    echo "FAIL approve ${project_path}!${iid}: HTTP ${http_code}" >&2
    echo "  response: $(echo "$body" | head -c 400)" >&2
    fail=$((fail + 1))
  fi
done < <(echo "$mrs" | jq -c '.[]')

{
  echo "RELEASE_APPROVED=1"
  echo "APPROVED_BY=${GITLAB_USER_LOGIN:-ci}"
  echo "APPROVED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "RELEASE_BRANCH=${branch}"
  echo "RELEASE_APPROVE_PIPELINE_ID=${CI_PIPELINE_ID:-0}"
  echo "RELEASE_APPROVE_OK=${ok}"
  echo "RELEASE_APPROVE_SKIP=${skip}"
  echo "RELEASE_APPROVE_FAIL=${fail}"
} >>"$approve_env"

echo ""
echo "=== SUMMARY approve ok=${ok} skip=${skip} fail=${fail} ==="
echo "Artifact: release_approve.env"

if [[ "$fail" -gt 0 ]]; then
  echo "ERROR: approve finished with failures. Fix MRs above before merge." >&2
  exit 1
fi

if [[ "$ok" -eq 0 && "$skip" -eq 0 ]]; then
  echo "ERROR: no MRs were approved or skipped unexpectedly." >&2
  exit 1
fi

exit 0
