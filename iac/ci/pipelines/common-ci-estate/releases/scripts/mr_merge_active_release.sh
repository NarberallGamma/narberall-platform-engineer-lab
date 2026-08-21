#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release_lib.sh
source "${SCRIPT_DIR}/release_lib.sh"

release_log_header "mr_merge_active_release"

release_require_current_branch
release_require_token

branch="$RELEASE_CURRENT_BRANCH"

if [[ "${RELEASE_APPROVED:-}" != "1" ]]; then
  echo "ERROR: RELEASE_APPROVED != 1 in this pipeline." >&2
  echo "Cause: run manual job release-02-approve-all-mrs in the SAME pipeline before merge." >&2
  echo "Fix: Play release-02-approve-all-mrs, wait for success, then Play release-03-merge-all-mrs." >&2
  exit 2
fi

if [[ -n "${RELEASE_APPROVE_PIPELINE_ID:-}" && -n "${CI_PIPELINE_ID:-}" ]]; then
  if [[ "$RELEASE_APPROVE_PIPELINE_ID" != "$CI_PIPELINE_ID" ]]; then
    echo "ERROR: approve artifact is from pipeline #${RELEASE_APPROVE_PIPELINE_ID}, current pipeline #${CI_PIPELINE_ID}." >&2
    echo "Cause: merge started in a new pipeline without approve in this run." >&2
    echo "Fix: in THIS pipeline run approve first, then merge (do not use approve from an older pipeline)." >&2
    exit 2
  fi
fi

if [[ "${RELEASE_BRANCH:-}" != "$branch" ]]; then
  echo "ERROR: approve artifact branch '${RELEASE_BRANCH:-<unset>}' != active '${branch}'." >&2
  exit 2
fi

if [[ "${RELEASE_APPROVE_IDEMPOTENT:-}" == "already_merged" ]]; then
  echo "ERROR: approve reported release already merged (idempotent); nothing to merge." >&2
  echo "Cause: all MRs for '${branch}' are already in ${RELEASE_TARGET_BRANCH:-main}." >&2
  echo "Fix: start a new release (new upgrade branch) or use release-04-revert-all-mrs to roll back." >&2
  exit 1
fi

mrs="$(release_list_open_release_mrs "$branch")"
count="$(echo "$mrs" | jq 'length')"
merged_count="$(release_list_merged_release_mrs "$branch" | jq 'length')"

echo "Open MRs to merge: ${count}"
echo "Merged MRs (reference): ${merged_count}"

if [[ "$count" -eq 0 ]]; then
  release_print_release_state "$branch"
  echo ""
  if [[ "$merged_count" -gt 0 ]]; then
    echo "ERROR: cannot merge: 0 open MRs, ${merged_count} already merged." >&2
    echo "Cause: release '${branch}' was already cut over to ${RELEASE_TARGET_BRANCH:-main}." >&2
    echo "Fix: verify main in GitLab/ArgoCD; for next release use a new upgrade branch." >&2
  else
    echo "ERROR: cannot merge: no open or merged MRs for '${branch}'." >&2
    echo "Cause: MRs were never created or RELEASE_CURRENT_BRANCH is wrong." >&2
  fi
  exit 1
fi

echo ""
echo "MR list:"
echo "$mrs" | jq -r '.[] | "  \(.references.full) -> \(.target_branch) \(.web_url)"'

release_countdown "${RELEASE_MERGE_COUNTDOWN_SEC:-60}"

ok=0
skip=0
fail=0
idx=0
pause="${RELEASE_MERGE_PAUSE_SEC:-2}"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  idx=$((idx + 1))
  project_id="$(echo "$line" | jq -r '.project_id')"
  iid="$(echo "$line" | jq -r '.iid')"
  source_branch="$(echo "$line" | jq -r '.source_branch')"
  sha="$(echo "$line" | jq -r '.sha')"
  project_path="$(echo "$line" | jq -r '.references.full' | sed 's/!.*//')"

  echo ""
  echo "--- [${idx}/${count}] merge ${project_path}!${iid} ---"
  echo "source=${source_branch} target=${RELEASE_TARGET_BRANCH:-main} sha=${sha}"

  release_assert_branch_is_current "$source_branch"

  mr_state="$(release_api GET "/projects/${project_id}/merge_requests/${iid}" | jq -r '.state // "unknown"')"
  if [[ "$mr_state" == "merged" ]]; then
    echo "SKIP merge ${project_path}!${iid} (already merged, idempotent)"
    skip=$((skip + 1))
    continue
  fi
  if [[ "$mr_state" != "opened" ]]; then
    echo "FAIL merge ${project_path}!${iid}: MR state=${mr_state} (expected opened)" >&2
    fail=$((fail + 1))
    continue
  fi

  is_draft="$(echo "$line" | jq -r '.draft // false')"
  if [[ "$is_draft" == "true" ]] || release_mr_is_draft "$project_id" "$iid"; then
    if [[ "${RELEASE_UNDRAFT_DRAFT_MRS:-}" == "1" ]]; then
      echo "DRAFT ${project_path}!${iid}: RELEASE_UNDRAFT_DRAFT_MRS=1, marking ready..."
      if release_mr_mark_ready "$project_id" "$iid"; then
        echo "OK mark ready ${project_path}!${iid}"
      else
        echo "SKIP merge ${project_path}!${iid} (still draft after undraft attempt)"
        skip=$((skip + 1))
        continue
      fi
    else
      echo "SKIP merge ${project_path}!${iid} (draft MR; not mergeable via API: mark as ready in UI or re-run with RELEASE_UNDRAFT_DRAFT_MRS=1)"
      skip=$((skip + 1))
      continue
    fi
  fi

  mr_meta="$(release_api GET "/projects/${project_id}/merge_requests/${iid}")"
  if [[ "$(echo "$mr_meta" | jq -r '.has_conflicts // false')" == "true" ]]; then
    echo "SKIP merge ${project_path}!${iid} (merge conflicts with ${RELEASE_TARGET_BRANCH:-main}; rebase upgrade branch in GitLab UI)"
    skip=$((skip + 1))
    continue
  fi

  payload="$(jq -n \
    --arg msg "Release merge ${branch} -> ${RELEASE_TARGET_BRANCH:-main} (pipeline ${CI_PIPELINE_ID:-n/a})" \
    '{merge_commit_message: $msg, squash: false, should_remove_source_branch: false}')"

  tmp="$(mktemp)"
  http_code="$(release_api_http PUT "/projects/${project_id}/merge_requests/${iid}/merge?sha=$(release_urlencode "$sha")" "$tmp" -d "$payload")"
  body="$(cat "$tmp")"
  rm -f "$tmp"

  if release_http_is_success "$http_code"; then
    merge_sha="$(echo "$body" | jq -r '.merge_commit_sha // .sha // "unknown"')"
    echo "OK merged ${project_path}!${iid} merge_sha=${merge_sha}"
    ok=$((ok + 1))
    comment="Merged to \`${RELEASE_TARGET_BRANCH:-main}\` via common-ci \`release-03-merge-all-mrs\`.

- Pipeline: ${CI_PIPELINE_URL:-n/a}
- Triggered by: @${GITLAB_USER_LOGIN:-unknown}
- Source branch preserved: \`${source_branch}\`
- squash: false"
    release_mr_comment "$project_id" "$iid" "$comment" || true
  elif release_http_body_indicates_already_merged "$body"; then
    echo "SKIP merge ${project_path}!${iid} (API: already merged, idempotent)"
    skip=$((skip + 1))
  elif [[ "$http_code" == "405" ]] && echo "$body" | grep -qiE 'draft|not allowed'; then
    echo "SKIP merge ${project_path}!${iid} (HTTP 405 draft/not allowed: mark MR as ready)"
    skip=$((skip + 1))
  elif [[ "$http_code" == "405" ]]; then
    echo "SKIP merge ${project_path}!${iid} (HTTP 405 not mergeable: check conflicts/approvals/pipeline in GitLab UI)"
    skip=$((skip + 1))
  else
    echo "FAIL merge ${project_path}!${iid}: HTTP ${http_code}" >&2
    echo "  response: $(echo "$body" | head -c 500)" >&2
    fail=$((fail + 1))
  fi

  if [[ "$idx" -lt "$count" ]]; then
    sleep "$pause"
  fi
done < <(echo "$mrs" | jq -c 'sort_by(.references.full) | .[]')

echo ""
echo "=== SUMMARY merge ok=${ok} skip=${skip} fail=${fail} ==="

if [[ "$fail" -gt 0 ]]; then
  echo "ERROR: merge finished with failures. Check MR conflicts/approvals in GitLab UI." >&2
  exit 1
fi

if [[ "$ok" -eq 0 && "$skip" -eq 0 ]]; then
  echo "ERROR: no MRs merged or skipped." >&2
  exit 1
fi

exit 0
