#!/usr/bin/env bash
# Shared helpers for estate release-upgrade GitLab CI (common-ci/releases).
set -euo pipefail

RELEASE_NEW_BRANCH_SHA="0000000000000000000000000000000000000000"

release_install_tools() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq not found in base-runner image; rebuild base-runner with jq in Dockerfile" >&2
    exit 2
  fi
}

release_log_header() {
  local script_name="$1"
  echo "=== ${script_name} ==="
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "gitlab_host=${CI_SERVER_HOST:-${GITLAB_HOST:-unknown}}"
  echo "release_current_branch=${RELEASE_CURRENT_BRANCH:-<unset>}"
  echo "release_target_branch=${RELEASE_TARGET_BRANCH:-main}"
  echo "trigger_user=${GITLAB_USER_LOGIN:-ci}"
  echo "trigger_user_name=${GITLAB_USER_NAME:-ci}"
  echo "ci_pipeline_id=${CI_PIPELINE_ID:-n/a}"
  echo "ci_pipeline_url=${CI_PIPELINE_URL:-n/a}"
}

release_urlencode() {
  jq -rn --arg v "$1" '$v|@uri'
}

release_require_token() {
  if [[ -z "${RELEASE_BOT_TOKEN:-}" ]]; then
    echo "ERROR: RELEASE_BOT_TOKEN is not set (group CI/CD variable on estate)" >&2
    exit 2
  fi
}

release_branch_pattern() {
  echo "${RELEASE_BRANCH_PATTERN:-^upgrade/shop-app-[0-9.]+-estate-[0-9.]+-(preprod|prod)$}"
}

release_branch_matches_pattern() {
  local branch="${1:-}"
  local pattern
  pattern="$(release_branch_pattern)"
  [[ "$branch" =~ $pattern ]]
}

release_resolve_current_branch() {
  if [[ -n "${RELEASE_BRANCH:-}" ]]; then
    if ! release_branch_matches_pattern "$RELEASE_BRANCH"; then
      echo "ERROR: RELEASE_BRANCH pipeline variable invalid: ${RELEASE_BRANCH}" >&2
      exit 2
    fi
    export RELEASE_CURRENT_BRANCH="$RELEASE_BRANCH"
    return 0
  fi
  if [[ -z "${RELEASE_CURRENT_BRANCH:-}" ]]; then
    echo "ERROR: RELEASE_CURRENT_BRANCH is not set (auto-set on first push of a new upgrade branch, or pass RELEASE_BRANCH when running cutover pipeline)" >&2
    exit 2
  fi
  if ! release_branch_matches_pattern "$RELEASE_CURRENT_BRANCH"; then
    echo "ERROR: RELEASE_CURRENT_BRANCH invalid: ${RELEASE_CURRENT_BRANCH}" >&2
    exit 2
  fi
}

release_require_current_branch() {
  release_resolve_current_branch
}

release_derive_title_prefix() {
  local branch="$1"
  if [[ "$branch" =~ ^upgrade/shop-app-([0-9.]+)-estate-([0-9.]+)-(preprod|prod)$ ]]; then
    local app_ver="${BASH_REMATCH[1]}"
    local est_ver="${BASH_REMATCH[2]}"
    local env="${BASH_REMATCH[3]}"
    if [[ "$env" == "preprod" ]]; then
      echo "PREPROD shop-app ${app_ver} / estate ${est_ver}"
    else
      echo "PROD shop-app ${app_ver} / estate ${est_ver}"
    fi
    return 0
  fi
  echo "${RELEASE_TITLE_PREFIX:-Release}: ${branch}"
}

release_upsert_group_variable() {
  local key="$1"
  local value="$2"
  local masked="${3:-false}"
  local protected="${4:-true}"
  local gpath group_id payload tmp http_code
  gpath="$(release_group_path_encoded)"
  group_id="$(release_api GET "/groups/${gpath}" | jq -r '.id')"
  payload="$(jq -n \
    --arg k "$key" --arg v "$value" \
    --argjson masked "$masked" --argjson protected "$protected" \
    '{key: $k, value: $v, masked: $masked, protected: $protected}')"
  tmp="$(mktemp)"
  http_code="$(curl -sS -o "$tmp" -w '%{http_code}' -X PUT \
    -H "PRIVATE-TOKEN: ${RELEASE_BOT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${CI_API_V4_URL}/groups/${group_id}/variables/${key}" || true)"
  if [[ "$http_code" != "200" ]]; then
    http_code="$(curl -sS -o "$tmp" -w '%{http_code}' -X POST \
      -H "PRIVATE-TOKEN: ${RELEASE_BOT_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "${CI_API_V4_URL}/groups/${group_id}/variables" || true)"
  fi
  if [[ ! "$http_code" =~ ^2 ]]; then
    echo "WARN: group variable ${key} HTTP ${http_code}: $(head -c 200 "$tmp")" >&2
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
  return 0
}

# On first push of a new upgrade branch, register it as the active release for cutover jobs.
release_register_active_branch() {
  local branch="$1"
  release_require_token
  if ! release_branch_matches_pattern "$branch"; then
    echo "SKIP register: branch does not match release pattern"
    return 0
  fi
  if [[ "${RELEASE_CURRENT_BRANCH:-}" == "$branch" ]]; then
    echo "OK register: RELEASE_CURRENT_BRANCH already ${branch}"
    return 0
  fi
  local title_prefix
  title_prefix="$(release_derive_title_prefix "$branch")"
  echo "REGISTER active release branch: ${branch} (was: ${RELEASE_CURRENT_BRANCH:-<unset>})"
  # protected=false: job runs on a new upgrade/* branch (not protected); must read/update these vars.
  release_upsert_group_variable "RELEASE_CURRENT_BRANCH" "$branch" false false
  release_upsert_group_variable "RELEASE_TITLE_PREFIX" "$title_prefix" false false || true
  export RELEASE_CURRENT_BRANCH="$branch"
  export RELEASE_TITLE_PREFIX="$title_prefix"
  echo "OK registered RELEASE_CURRENT_BRANCH=${branch}"
}

release_api() {
  local method="$1"
  local path="$2"
  shift 2
  release_require_token
  curl -fsS -X "$method" \
    -H "PRIVATE-TOKEN: ${RELEASE_BOT_TOKEN}" \
    -H "Content-Type: application/json" \
    "${CI_API_V4_URL}${path}" "$@"
}

release_api_job() {
  local method="$1"
  local path="$2"
  shift 2
  curl -fsS -X "$method" \
    -H "JOB-TOKEN: ${CI_JOB_TOKEN}" \
    -H "Content-Type: application/json" \
    "${CI_API_V4_URL}${path}" "$@"
}

release_group_path_encoded() {
  release_urlencode "${RELEASE_GROUP_PATH:-estate}"
}

release_wait_for_mr_ready() {
  local project_id="$1"
  local mr_iid="$2"
  local attempt max=30
  for ((attempt = 1; attempt <= max; attempt++)); do
    local status
    status="$(release_api GET "/projects/${project_id}/merge_requests/${mr_iid}" | jq -r '.detailed_merge_status // .merge_status // "unknown"')"
    case "$status" in
      checking|approvals_syncing|preparing|unchecked)
        echo "MR !${mr_iid} status=${status}, wait_ready attempt ${attempt}/${max}..."
        sleep 2
        ;;
      *)
        echo "MR !${mr_iid} ready (status=${status})"
        return 0
        ;;
    esac
  done
  echo "WARN: MR !${mr_iid} still not ready after ${max} attempts" >&2
  return 1
}

release_mr_comment() {
  local project_id="$1"
  local mr_iid="$2"
  local body="$3"
  local payload
  payload="$(jq -n --arg body "$body" '{body: $body}')"
  release_api POST "/projects/${project_id}/merge_requests/${mr_iid}/notes" -d "$payload" >/dev/null
}

release_list_open_release_mrs() {
  local branch="${1:-$RELEASE_CURRENT_BRANCH}"
  local target="${RELEASE_TARGET_BRANCH:-main}"
  local enc_branch enc_target gpath
  enc_branch="$(release_urlencode "$branch")"
  enc_target="$(release_urlencode "$target")"
  gpath="$(release_group_path_encoded)"
  release_api GET "/groups/${gpath}/merge_requests?state=opened&source_branch=${enc_branch}&target_branch=${enc_target}&per_page=100&scope=all"
}

release_list_merged_release_mrs() {
  local branch="${1:-$RELEASE_CURRENT_BRANCH}"
  local target="${RELEASE_TARGET_BRANCH:-main}"
  local enc_branch enc_target gpath
  enc_branch="$(release_urlencode "$branch")"
  enc_target="$(release_urlencode "$target")"
  gpath="$(release_group_path_encoded)"
  release_api GET "/groups/${gpath}/merge_requests?state=merged&source_branch=${enc_branch}&target_branch=${enc_target}&per_page=100&scope=all"
}

# Print open/merged counts and sample MR refs (diagnostics, no side effects).
release_print_release_state() {
  local branch="${1:-$RELEASE_CURRENT_BRANCH}"
  local target="${RELEASE_TARGET_BRANCH:-main}"
  local open_json merged_json open_count merged_count
  open_json="$(release_list_open_release_mrs "$branch")"
  merged_json="$(release_list_merged_release_mrs "$branch")"
  open_count="$(echo "$open_json" | jq 'length')"
  merged_count="$(echo "$merged_json" | jq 'length')"
  echo "=== RELEASE STATE (${branch} -> ${target}) ==="
  echo "open_mrs=${open_count} merged_mrs=${merged_count}"
  if [[ "$open_count" -gt 0 ]]; then
    echo "Open MRs:"
    echo "$open_json" | jq -r '.[] | "  \(.references.full) approved=\(.approved // false) \(.web_url)"'
  fi
  if [[ "$merged_count" -gt 0 ]]; then
    echo "Merged MRs (already in ${target}):"
    echo "$merged_json" | jq -r '.[] | "  \(.references.full) merged_at=\(.merged_at // "n/a")"'
  fi
  if [[ "$open_count" -eq 0 && "$merged_count" -gt 0 ]]; then
    echo "DIAGNOSTIC: release likely already cut over (merged MRs exist, none open)."
  elif [[ "$open_count" -eq 0 && "$merged_count" -eq 0 ]]; then
    echo "DIAGNOSTIC: no MRs for this branch. Push upgrade branch (first push creates MR) or check RELEASE_CURRENT_BRANCH."
  fi
}

release_mr_is_approved() {
  local project_id="$1"
  local mr_iid="$2"
  local approved
  approved="$(release_api GET "/projects/${project_id}/merge_requests/${mr_iid}" | jq -r '.approved // false')"
  [[ "$approved" == "true" ]]
}

release_mr_is_draft() {
  local project_id="$1"
  local mr_iid="$2"
  local draft
  draft="$(release_api GET "/projects/${project_id}/merge_requests/${mr_iid}" | jq -r '.draft // false')"
  [[ "$draft" == "true" ]]
}

# Mark a draft MR as ready (undraft). Returns 0 on success.
release_mr_mark_ready() {
  local project_id="$1"
  local mr_iid="$2"
  local mr title new_title payload tmp http_code body
  mr="$(release_api GET "/projects/${project_id}/merge_requests/${mr_iid}")"
  title="$(echo "$mr" | jq -r '.title // ""')"
  new_title="$title"
  new_title="${new_title#Draft: }"
  new_title="${new_title#Draft:}"
  new_title="${new_title#\[Draft\] }"
  new_title="${new_title#(Draft) }"

  if [[ -n "$title" && "$new_title" != "$title" ]]; then
    payload="$(jq -n --arg t "$new_title" '{title: $t}')"
    tmp="$(mktemp)"
    http_code="$(release_api_http PUT "/projects/${project_id}/merge_requests/${mr_iid}" "$tmp" -d "$payload")"
    body="$(cat "$tmp")"
    rm -f "$tmp"
    if release_http_is_success "$http_code"; then
      return 0
    fi
    echo "WARN: mark ready via title ${project_id}!${mr_iid} HTTP ${http_code}: $(echo "$body" | head -c 200)" >&2
  fi

  if ! release_mr_is_draft "$project_id" "$mr_iid"; then
    return 0
  fi

  payload="$(jq -n '{draft: false, work_in_progress: false}')"
  tmp="$(mktemp)"
  http_code="$(release_api_http PUT "/projects/${project_id}/merge_requests/${mr_iid}" "$tmp" -d "$payload")"
  body="$(cat "$tmp")"
  rm -f "$tmp"
  if release_http_is_success "$http_code"; then
    return 0
  fi
  echo "WARN: mark ready ${project_id}!${mr_iid} HTTP ${http_code}: $(echo "$body" | head -c 200)" >&2
  return 1
}

release_api_http() {
  local method="$1"
  local path="$2"
  local out_file="$3"
  shift 3
  release_require_token
  curl -sS -o "$out_file" -w '%{http_code}' -X "$method" \
    -H "PRIVATE-TOKEN: ${RELEASE_BOT_TOKEN}" \
    -H "Content-Type: application/json" \
    "${CI_API_V4_URL}${path}" "$@"
}

release_http_is_success() {
  [[ "$1" =~ ^2 ]]
}

release_http_body_indicates_already_approved() {
  local body="$1"
  [[ "$body" == *"already approved"* ]] || [[ "$body" == *"Already approved"* ]]
}

release_http_body_indicates_already_merged() {
  local body="$1"
  [[ "$body" == *"already been merged"* ]] || [[ "$body" == *"Already merged"* ]] \
    || [[ "$body" == *"merge request has already been merged"* ]] || [[ "$body" == *"Cannot merge"* && "$body" == *"merged"* ]]
}

release_assert_branch_is_current() {
  local branch="$1"
  release_require_current_branch
  if [[ "$branch" != "$RELEASE_CURRENT_BRANCH" ]]; then
    echo "ERROR: branch '${branch}' != active RELEASE_CURRENT_BRANCH '${RELEASE_CURRENT_BRANCH}'" >&2
    exit 2
  fi
}

release_countdown() {
  local sec="${1:-60}"
  echo ""
  echo "!!! MERGE RELEASE TO ${RELEASE_TARGET_BRANCH:-main} !!!"
  echo "Active branch: ${RELEASE_CURRENT_BRANCH}"
  echo "Triggered by: ${GITLAB_USER_NAME:-} (${GITLAB_USER_LOGIN:-ci})"
  echo "Merge starts in ${sec} seconds. Cancel pipeline to abort."
  echo ""
  local i
  for ((i = sec; i >= 1; i--)); do
    echo "  ${i}..."
    sleep 1
  done
  echo "Countdown finished, proceeding."
}

release_is_new_branch_push() {
  [[ "${CI_COMMIT_BEFORE_SHA:-}" == "$RELEASE_NEW_BRANCH_SHA" ]]
}
