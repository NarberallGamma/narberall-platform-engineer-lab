#!/usr/bin/env bash
# Configure GitLab group `estate` for release CI (PREPROD or PROD).
# Requires GITLAB_ADMIN_TOKEN in the environment (value CHANGE_ME until set).
# Does not print token values. Log: OUT file (no secrets).
#
# Usage:
#   bash setup_gitlab_release_admin.sh --env PREPROD [--dry-run]
#   bash setup_gitlab_release_admin.sh --env PROD [--dry-run]
set -euo pipefail

ENV_NAME=""
DRY_RUN=false
OUT=""

usage() {
  cat <<'EOF'
setup_gitlab_release_admin.sh --env PREPROD|PROD [--dry-run] [--out PATH]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_NAME="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --out) OUT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[[ "$ENV_NAME" == "PREPROD" || "$ENV_NAME" == "PROD" ]] || {
  echo "ERROR: --env PREPROD|PROD required" >&2
  exit 1
}

if [[ -z "$OUT" ]]; then
  OUT="./gitlab_release_admin_${ENV_NAME}.out"
fi
mkdir -p "$(dirname "$OUT")"
exec > >(tee "$OUT") 2>&1

if [[ "$ENV_NAME" == "PREPROD" ]]; then
  GITLAB_HOST="${PREPROD_GITLAB_HOST:-gitlab-preprod.example.com}"
  ADMIN_TOKEN="${GITLAB_ADMIN_TOKEN:-CHANGE_ME}"
  RELEASE_BRANCH="${RELEASE_CURRENT_BRANCH:-upgrade/shop-app-1.0-estate-1.0-preprod}"
  TITLE_PREFIX="${RELEASE_TITLE_PREFIX:-PREPROD shop-app 1.0 / estate 1.0}"
else
  GITLAB_HOST="${PROD_GITLAB_HOST:-gitlab.example.com}"
  ADMIN_TOKEN="${GITLAB_ADMIN_TOKEN:-CHANGE_ME}"
  RELEASE_BRANCH="${RELEASE_CURRENT_BRANCH:-upgrade/shop-app-1.0-estate-1.0-prod}"
  TITLE_PREFIX="${RELEASE_TITLE_PREFIX:-PROD shop-app release}"
fi

GROUP_PATH="estate"
BOT_USERNAME="release-bot"
BOT_NAME="Release Bot"
BOT_EMAIL="release-bot@example.com"
API="https://${GITLAB_HOST}/api/v4"

if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "CHANGE_ME" ]]; then
  echo "ERROR: GITLAB_ADMIN_TOKEN is not set (placeholder CHANGE_ME)" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  apk add --no-cache jq >/dev/null 2>&1 || apt-get update >/dev/null 2>&1 && apt-get install -y jq >/dev/null 2>&1 || true
fi
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 2; }

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

api() {
  local method="$1"
  local path="$2"
  shift 2
  curl -fsS -X "$method" \
    -H "PRIVATE-TOKEN: ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    "${API}${path}" "$@"
}

api_maybe() {
  local method="$1"
  local path="$2"
  shift 2
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -o "$tmp" -w '%{http_code}' -X "$method" \
    -H "PRIVATE-TOKEN: ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    "${API}${path}" "$@" || true)"
  if [[ "$code" =~ ^2 ]]; then
    cat "$tmp"
    rm -f "$tmp"
    return 0
  fi
  log "API ${method} ${path} -> HTTP ${code}"
  head -c 500 "$tmp" || true
  echo ""
  rm -f "$tmp"
  return 1
}

urlenc() { jq -rn --arg v "$1" '$v|@uri'; }

upsert_group_variable() {
  local key="$1"
  local value="$2"
  local masked="${3:-false}"
  local protected="${4:-true}"
  local tmp http_code payload
  tmp="$(mktemp)"
  payload="$(jq -n \
    --arg k "$key" --arg v "$value" \
    --argjson masked "$masked" --argjson protected "$protected" \
    '{key: $k, value: $v, masked: $masked, protected: $protected}')"
  http_code="$(curl -sS -o "$tmp" -w '%{http_code}' \
    -H "PRIVATE-TOKEN: ${ADMIN_TOKEN}" \
    "${API}/groups/${GROUP_ID}/variables/${key}" || true)"
  if [[ "$http_code" == "200" ]]; then
    log "UPDATE group variable ${key} (masked=${masked})"
    [[ "$DRY_RUN" == true ]] && { rm -f "$tmp"; return 0; }
    http_code="$(curl -sS -o "$tmp" -w '%{http_code}' -X PUT \
      -H "PRIVATE-TOKEN: ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "${API}/groups/${GROUP_ID}/variables/${key}" || true)"
  else
    log "CREATE group variable ${key} (masked=${masked})"
    [[ "$DRY_RUN" == true ]] && { rm -f "$tmp"; return 0; }
    http_code="$(curl -sS -o "$tmp" -w '%{http_code}' -X POST \
      -H "PRIVATE-TOKEN: ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "${API}/groups/${GROUP_ID}/variables" || true)"
  fi
  if [[ ! "$http_code" =~ ^2 ]]; then
    log "WARN: group variable ${key} HTTP ${http_code}: $(head -c 200 "$tmp")"
  else
    log "OK group variable ${key}"
  fi
  rm -f "$tmp"
}

log "=== GitLab release admin setup env=${ENV_NAME} host=${GITLAB_HOST} dry_run=${DRY_RUN} ==="
log "defaults branch=${RELEASE_BRANCH} title=${TITLE_PREFIX}"

me="$(api GET "/user")"
log "API user: $(echo "$me" | jq -r '.username') id=$(echo "$me" | jq -r '.id') is_admin=$(echo "$me" | jq -r '.is_admin // false')"

group="$(api GET "/groups/$(urlenc "$GROUP_PATH")")"
GROUP_ID="$(echo "$group" | jq -r '.id')"
GROUP_ENC="$(urlenc "$GROUP_PATH")"
log "Group ${GROUP_PATH} id=${GROUP_ID}"

# --- release-bot user ---
bot_id="$(api_maybe GET "/users?username=$(urlenc "$BOT_USERNAME")" | jq -r '.[0].id // empty' || true)"
bot_pat=""

if [[ -z "$bot_id" || "$bot_id" == "null" ]]; then
  log "CREATE user ${BOT_USERNAME}"
  if [[ "$DRY_RUN" != true ]]; then
    bot_pass="$(openssl rand -base64 24 2>/dev/null || head -c 24 /dev/urandom | base64)"
    payload="$(jq -n \
      --arg email "$BOT_EMAIL" \
      --arg username "$BOT_USERNAME" \
      --arg name "$BOT_NAME" \
      --arg password "$bot_pass" \
      '{email: $email, username: $username, name: $name, password: $password, skip_confirmation: true, force_random_password: false}')"
    if bot_json="$(api_maybe POST "/users" -d "$payload")"; then
      bot_id="$(echo "$bot_json" | jq -r '.id')"
      log "OK user ${BOT_USERNAME} id=${bot_id} (password not logged; use PAT below)"
    else
      log "WARN: could not create user (need admin API). Will use admin token for RELEASE_BOT_TOKEN."
    fi
  fi
else
  log "User ${BOT_USERNAME} exists id=${bot_id}"
fi

if [[ -n "$bot_id" && "$bot_id" != "null" && "$DRY_RUN" != true ]]; then
  members="$(api_maybe GET "/groups/${GROUP_ID}/members/all?per_page=100" || echo '[]')"
  if ! echo "$members" | jq -e --argjson uid "$bot_id" '.[] | select(.id == $uid)' >/dev/null 2>&1; then
    log "ADD ${BOT_USERNAME} to group as Owner (50): required to upsert group CI variables"
    api_maybe POST "/groups/${GROUP_ID}/members" \
      -d "$(jq -n --argjson uid "$bot_id" '{user_id: $uid, access_level: 50}')" >/dev/null || \
      log "WARN: add member failed"
  else
    log "ENSURE ${BOT_USERNAME} access_level=Owner (50) for group variables API"
    api_maybe PUT "/groups/${GROUP_ID}/members/${bot_id}" \
      -d '{"access_level": 50}' >/dev/null || \
      log "WARN: elevate member failed (may already be Owner)"
  fi

  log "CREATE PAT for ${BOT_USERNAME} (release-ci)"
  pat_payload="$(jq -n \
    --arg name "release-ci-$(date +%Y%m%d)" \
    '{name: $name, scopes: ["api"], expires_at: null}')"
  if pat_json="$(api_maybe POST "/users/${bot_id}/personal_access_tokens" -d "$pat_payload")"; then
    bot_pat="$(echo "$pat_json" | jq -r '.token // empty')"
    if [[ -n "$bot_pat" && "$bot_pat" != "null" ]]; then
      log "OK bot PAT created (value not printed, len=${#bot_pat})"
    else
      log "WARN: PAT response without token field; using admin token for group var"
      bot_pat="$ADMIN_TOKEN"
    fi
  else
    log "WARN: PAT create failed; using admin token for RELEASE_BOT_TOKEN group variable"
    bot_pat="$ADMIN_TOKEN"
  fi
else
  bot_pat="$ADMIN_TOKEN"
fi

# --- group CI variables (RELEASE_BOT_TOKEN only; branch/title auto-register on first push) ---
# masked=true, protected=false: release-mr-create runs on a new unprotected upgrade/* branch.
release_bot_for_var="${bot_pat:-$ADMIN_TOKEN}"
upsert_group_variable "RELEASE_BOT_TOKEN" "$release_bot_for_var" true false
log "SKIP manual RELEASE_CURRENT_BRANCH / RELEASE_TITLE_PREFIX (auto-set by release-mr-create on first push)"

# --- GitLab edition / approval rules ---
version_json="$(api GET "/version")"
enterprise="$(echo "$version_json" | jq -r '.enterprise // false')"
gitlab_ver="$(echo "$version_json" | jq -r '.version // "unknown"')"
log "GitLab version=${gitlab_ver} enterprise=${enterprise}"

if [[ "$enterprise" == "true" ]]; then
  rules="$(api_maybe GET "/groups/${GROUP_ID}/approval_rules" || echo '[]')"
  if [[ -n "$bot_id" && "$bot_id" != "null" ]]; then
    if echo "$rules" | jq -e '.[] | select(.name == "Release bot")' >/dev/null 2>&1; then
      log "OK approval rule 'Release bot' exists"
    else
      log "CREATE group approval rule 'Release bot' (Premium/Ultimate)"
      if [[ "$DRY_RUN" != true ]]; then
        rule_payload="$(jq -n \
          --argjson uid "$bot_id" \
          '{name: "Release bot", approvals_required: 1, user_ids: [$uid]}')"
        api_maybe POST "/groups/${GROUP_ID}/approval_rules" -d "$rule_payload" >/dev/null && \
          log "OK approval rule created" || \
          log "WARN: group approval rule failed; try feature flag approval_group_rules or project rules API"
      fi
    fi
  fi
  if [[ "$DRY_RUN" != true ]]; then
    reauth_payload='{"require_reauthentication_to_approve": false}'
    if api_maybe PUT "/groups/${GROUP_ID}/merge_request_approval_settings" -d "$reauth_payload" >/dev/null; then
      log "OK disabled require_reauthentication_to_approve (group)"
    else
      log "WARN: group merge_request_approval_settings API unavailable"
    fi
  fi
else
  log "GitLab CE (enterprise=false): group approval rules and MR approval settings API are not available (Premium/Ultimate)."
  log "On CE, projects have approvals_before_merge=null; release approve job is optional, merge may work without approval rules."
  log "After an upgrade to Premium, re-run this script or use API docs in releases/README.md"
fi

# --- job token: allow estate group jobs to read common-ci (clone release scripts) ---
common_ci_id=""
if proj_json="$(api_maybe GET "/projects/${GROUP_ID}")"; then
  if echo "$proj_json" | jq -e '.path_with_namespace == "estate/common-ci"' >/dev/null 2>&1; then
    common_ci_id="$GROUP_ID"
  fi
fi
if [[ -z "$common_ci_id" ]]; then
  search="$(api_maybe GET "/projects?search=common-ci&search_namespaces=true&per_page=20" || echo '[]')"
  common_ci_id="$(echo "$search" | jq -r '.[] | select(.path_with_namespace=="estate/common-ci") | .id' | head -1)"
fi
if [[ -n "$common_ci_id" && "$common_ci_id" != "null" ]]; then
  log "common-ci project id=${common_ci_id}"
  if [[ "$DRY_RUN" != true ]]; then
    scope="$(api_maybe GET "/projects/${common_ci_id}/job_token_scope" || echo '{}')"
    log "job_token_scope inbound_enabled=$(echo "$scope" | jq -r '.inbound_enabled // "unknown"')"
    groups_list="$(api_maybe GET "/projects/${common_ci_id}/job_token_scope/groups_allowlist" || echo '[]')"
    if echo "$groups_list" | jq -e --argjson gid "$GROUP_ID" '.[] | select(.id == $gid)' >/dev/null 2>&1; then
      log "OK groups_allowlist already contains group id=${GROUP_ID}"
    else
      log "ADD group estate to common-ci job token groups allowlist (API)"
      payload="$(jq -n --argjson gid "$GROUP_ID" '{target_group_id: $gid}')"
      if api_maybe POST "/projects/${common_ci_id}/job_token_scope/groups_allowlist" -d "$payload" >/dev/null; then
        log "OK groups_allowlist: estate can use job token against common-ci"
      else
        log "WARN: POST /projects/${common_ci_id}/job_token_scope/groups_allowlist failed"
        log "UI: Project estate/common-ci -> Settings -> CI/CD -> Job token permissions -> Add group estate"
      fi
    fi
  fi
else
  log "WARN: common-ci project id not resolved"
fi

log "NOTE: Job token permissions live on PROJECT common-ci, not on group Settings (GitLab 15.9+)."

log "=== DONE env=${ENV_NAME} log=${OUT} ==="
