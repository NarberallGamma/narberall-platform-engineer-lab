#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release_lib.sh
source "${SCRIPT_DIR}/release_lib.sh"

release_log_header "mr_create_on_push"

if [[ -z "${CI_PROJECT_ID:-}" ]]; then
  echo "ERROR: must run in a project pipeline (CI_PROJECT_ID missing)" >&2
  exit 2
fi

if ! release_is_new_branch_push; then
  echo "SKIP: not a new branch push (CI_COMMIT_BEFORE_SHA=${CI_COMMIT_BEFORE_SHA:-<empty>})"
  echo "Existing MR will update automatically on new commits."
  exit 0
fi

branch="${CI_COMMIT_BRANCH:-}"
if ! release_branch_matches_pattern "$branch"; then
  echo "SKIP: branch '${branch}' does not match release pattern"
  exit 0
fi

release_register_active_branch "$branch"
release_resolve_current_branch

target="${RELEASE_TARGET_BRANCH:-main}"
title_prefix="$(release_derive_title_prefix "$branch")"
title="${title_prefix}: ${CI_PROJECT_NAME}"

echo "project=${CI_PROJECT_PATH}"
echo "source_branch=${CI_COMMIT_BRANCH}"
echo "target_branch=${target}"
echo "pushed_by=${GITLAB_USER_LOGIN:-unknown}"

enc_sb="$(release_urlencode "$CI_COMMIT_BRANCH")"
enc_tb="$(release_urlencode "$target")"
existing="$(release_api_job GET "/projects/${CI_PROJECT_ID}/merge_requests?state=opened&source_branch=${enc_sb}&target_branch=${enc_tb}" 2>/dev/null || echo '[]')"

if [[ "$(echo "$existing" | jq 'length')" -gt 0 ]]; then
  iid="$(echo "$existing" | jq -r '.[0].iid')"
  url="$(echo "$existing" | jq -r '.[0].web_url')"
  echo "SKIP create: open MR already exists !${iid} ${url}"
  exit 0
fi

payload="$(jq -n \
  --arg sb "$CI_COMMIT_BRANCH" \
  --arg tb "$target" \
  --arg t "$title" \
  --arg desc "Auto-created on first push of release branch. Pushed by: ${GITLAB_USER_LOGIN:-unknown}. Pipeline: ${CI_PIPELINE_URL:-n/a}. Branch: ${branch}" \
  '{source_branch: $sb, target_branch: $tb, title: $t, description: $desc, remove_source_branch: false}')"

if mr="$(release_api_job POST "/projects/${CI_PROJECT_ID}/merge_requests" -d "$payload" 2>/dev/null)"; then
  :
elif [[ -n "${RELEASE_BOT_TOKEN:-}" ]]; then
  mr="$(release_api POST "/projects/${CI_PROJECT_ID}/merge_requests" -d "$payload")"
else
  echo "ERROR: create MR failed (JOB-TOKEN and RELEASE_BOT_TOKEN)" >&2
  exit 1
fi

iid="$(echo "$mr" | jq -r '.iid')"
url="$(echo "$mr" | jq -r '.web_url')"
echo "OK create_mr project=${CI_PROJECT_PATH} mr=!${iid} url=${url}"

comment="Release MR auto-created on first push of \`${CI_COMMIT_BRANCH}\`.

- Pushed by: @${GITLAB_USER_LOGIN:-unknown}
- Pipeline: ${CI_PIPELINE_URL:-n/a}
- Registered active branch: \`${RELEASE_CURRENT_BRANCH}\`"

release_mr_comment "$CI_PROJECT_ID" "$iid" "$comment" 2>/dev/null || echo "WARN: could not post MR comment (need RELEASE_BOT_TOKEN for notes)"

echo "=== done ==="
