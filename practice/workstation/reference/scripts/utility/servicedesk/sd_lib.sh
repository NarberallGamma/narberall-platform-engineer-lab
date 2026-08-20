#!/usr/bin/env bash
# Shared auth and HTTP helpers for Jira Server + JSM (URL from env).
set -euo pipefail

SD_ENV_FILE="${SD_ENV_FILE:-${HOME}/.config/ops/.env-lab}"

sd_load_env() {
  if [[ ! -f "$SD_ENV_FILE" ]]; then
    echo "ERROR: missing $SD_ENV_FILE (alias lab, see secrets-env README)" >&2
    return 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "$SD_ENV_FILE"
  set +a
  SD_BASE="${SERVICEDESK_BASE_URL:-}"
  if [[ -z "$SD_BASE" ]]; then
    echo "ERROR: set SERVICEDESK_BASE_URL in $SD_ENV_FILE" >&2
    return 1
  fi
  SD_BASE="${SD_BASE%/}"
  SD_EMAIL="${SERVICEDESK_USER_EMAIL:-}"
  SD_REST="${SERVICEDESK_CURSOR_REST_TOKEN:-}"
  SD_BEARER="${SERVICEDESK_CURSOR_TOKEN:-}"
  if [[ -z "$SD_REST" && -z "$SD_BEARER" ]]; then
    echo "ERROR: set SERVICEDESK_CURSOR_REST_TOKEN and/or SERVICEDESK_CURSOR_TOKEN" >&2
    return 1
  fi
}

# Prefer REST token (Basic) for POST; Bearer for read fallback.
sd_curl_get() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  if [[ -n "$SD_REST" && -n "$SD_EMAIL" ]]; then
    code="$(curl -sS -o "$tmp" -w '%{http_code}' \
      -u "${SD_EMAIL}:${SD_REST}" \
      -H "Accept: application/json" \
      --connect-timeout 20 --max-time 120 \
      "$url" || echo 000)"
  elif [[ -n "$SD_BEARER" ]]; then
    code="$(curl -sS -o "$tmp" -w '%{http_code}' \
      -H "Authorization: Bearer ${SD_BEARER}" \
      -H "Accept: application/json" \
      --connect-timeout 20 --max-time 120 \
      "$url" || echo 000)"
  else
    echo "ERROR: need REST+email or Bearer token for GET" >&2
    return 1
  fi
  SD_LAST_HTTP="$code"
  SD_LAST_BODY="$(cat "$tmp")"
  rm -f "$tmp"
  if [[ "$code" != 2* ]]; then
    echo "ERROR: HTTP $code for GET $url" >&2
    echo "$SD_LAST_BODY" | head -c 800 >&2
    return 1
  fi
}

sd_curl_post_json() {
  local url="$1"
  local json="$2"
  local tmp
  tmp="$(mktemp)"
  local code
  if [[ -n "$SD_REST" && -n "$SD_EMAIL" ]]; then
    code="$(curl -sS -o "$tmp" -w '%{http_code}' \
      -u "${SD_EMAIL}:${SD_REST}" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --connect-timeout 20 --max-time 120 \
      -X POST -d "$json" \
      "$url" || echo 000)"
  elif [[ -n "$SD_BEARER" ]]; then
    code="$(curl -sS -o "$tmp" -w '%{http_code}' \
      -H "Authorization: Bearer ${SD_BEARER}" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --connect-timeout 20 --max-time 120 \
      -X POST -d "$json" \
      "$url" || echo 000)"
  else
    echo "ERROR: need REST+email or Bearer for POST" >&2
    return 1
  fi
  SD_LAST_HTTP="$code"
  SD_LAST_BODY="$(cat "$tmp")"
  rm -f "$tmp"
  if [[ "$code" != 2* ]]; then
    echo "ERROR: HTTP $code for POST $url" >&2
    echo "$SD_LAST_BODY" | head -c 800 >&2
    return 1
  fi
}

# Single issue key only (no lists, wildcards, or JQL).
sd_validate_issue_key() {
  local key="${1:-}"
  if [[ ! "$key" =~ ^[A-Z][A-Z0-9]*-[0-9]+$ ]]; then
    echo "ERROR: invalid issue key '$key' (expected PROJECT-123, one issue only)" >&2
    return 1
  fi
  if [[ "$key" == *","* || "$key" == *" "* || "$key" == *"*"* || "$key" == *"?"* ]]; then
    echo "ERROR: issue key must be a single key, not a list or pattern" >&2
    return 1
  fi
}

# Mutating scripts must pass --confirm-write (or SD_CONFIRM_WRITE=yes for controlled automation).
sd_require_confirm_write() {
  if [[ "${SD_CONFIRM_WRITE:-}" == "yes" || "${1:-}" == "yes" ]]; then
    return 0
  fi
  echo "ERROR: write blocked. Pass --confirm-write for exactly one issue (no bulk)." >&2
  return 1
}

sd_require_confirm_create() {
  if [[ "${SD_CONFIRM_CREATE:-}" == "yes" || "${1:-}" == "yes" ]]; then
    return 0
  fi
  echo "ERROR: create blocked. Pass --confirm-create (creates one new issue only)." >&2
  return 1
}

sd_curl_put_json() {
  local url="$1"
  local json="$2"
  local tmp
  tmp="$(mktemp)"
  local code
  if [[ -n "$SD_REST" && -n "$SD_EMAIL" ]]; then
    code="$(curl -sS -o "$tmp" -w '%{http_code}' \
      -u "${SD_EMAIL}:${SD_REST}" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --connect-timeout 20 --max-time 120 \
      -X PUT -d "$json" \
      "$url" || echo 000)"
  elif [[ -n "$SD_BEARER" ]]; then
    code="$(curl -sS -o "$tmp" -w '%{http_code}' \
      -H "Authorization: Bearer ${SD_BEARER}" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --connect-timeout 20 --max-time 120 \
      -X PUT -d "$json" \
      "$url" || echo 000)"
  else
    echo "ERROR: need REST+email or Bearer for PUT" >&2
    return 1
  fi
  SD_LAST_HTTP="$code"
  SD_LAST_BODY="$(cat "$tmp")"
  rm -f "$tmp"
  if [[ "$code" != 2* && "$code" != 204 ]]; then
    echo "ERROR: HTTP $code for PUT $url" >&2
    echo "$SD_LAST_BODY" | head -c 800 >&2
    return 1
  fi
}

# Default estate client organisation on INFRA requests (Insight customfield_12604).
# REST create/update must send Insight object key, e.g. [{"key":"ORG-0001"}].
SD_ORG_LABEL="${SD_ORG_LABEL:-Example Org}"
SD_ORG_KEY="${SD_ORG_KEY:-ORG-0001}"
SD_INFRA_REQUEST_TYPE_ID="${SD_INFRA_REQUEST_TYPE_ID:-433}"
SD_INFRA_SERVICE_DESK_ID="${SD_INFRA_SERVICE_DESK_ID:-30}"

sd_period_to_jql_fragment() {
  local period="${1:-}"
  case "$period" in
    today) echo 'updated >= startOfDay()' ;;
    1d) echo 'updated >= -1d' ;;
    7d|week) echo 'updated >= -7d' ;;
    30d|month) echo 'updated >= -30d' ;;
    90d) echo 'updated >= -90d' ;;
    all|'') echo '' ;;
    *)
      echo "ERROR: unknown period '$period' (today|1d|7d|30d|90d|all)" >&2
      return 1
      ;;
  esac
}
