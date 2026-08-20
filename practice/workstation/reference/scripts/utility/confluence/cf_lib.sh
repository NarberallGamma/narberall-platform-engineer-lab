#!/usr/bin/env bash
# Shared auth and HTTP helpers for Confluence Server / DC (URL from env).
set -euo pipefail

CF_ENV_FILE="${CF_ENV_FILE:-${HOME}/.config/ops/.env-lab}"

cf_load_env() {
  if [[ ! -f "$CF_ENV_FILE" ]]; then
    echo "ERROR: missing $CF_ENV_FILE (alias lab, see secrets-env README)" >&2
    return 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "$CF_ENV_FILE"
  set +a
  CF_BASE="${CONFLUENCE_BASE_URL:-}"
  CF_BASE="${CF_BASE%/}"
  if [[ -z "$CF_BASE" ]]; then
    echo "ERROR: set CONFLUENCE_BASE_URL in $CF_ENV_FILE" >&2
    return 1
  fi
  CF_TOKEN="${CONFLUENCE_CURSOR_TOKEN:-${CONFLUENCE_PAT:-}}"
  CF_EMAIL="${CONFLUENCE_USER_EMAIL:-${SERVICEDESK_USER_EMAIL:-}}"
  if [[ -z "$CF_TOKEN" ]]; then
    echo "ERROR: set CONFLUENCE_CURSOR_TOKEN in $CF_ENV_FILE" >&2
    return 1
  fi
}

cf_curl_get() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -o "$tmp" -w '%{http_code}' \
    -H "Authorization: Bearer ${CF_TOKEN}" \
    -H "Accept: application/json" \
    --connect-timeout 20 --max-time 180 \
    "$url" 2>/dev/null || echo 000)"
  if [[ "$code" != 2* ]]; then
    if [[ -n "$CF_EMAIL" ]]; then
      code="$(curl -sS -o "$tmp" -w '%{http_code}' \
        -u "${CF_EMAIL}:${CF_TOKEN}" \
        -H "Accept: application/json" \
        --connect-timeout 20 --max-time 180 \
        "$url" 2>/dev/null || echo 000)"
    fi
  fi
  CF_LAST_HTTP="$code"
  CF_LAST_BODY="$(cat "$tmp")"
  rm -f "$tmp"
  if [[ "$code" != 2* ]]; then
    echo "ERROR: HTTP $code for GET $url" >&2
    echo "$CF_LAST_BODY" | head -c 800 >&2
    return 1
  fi
}

cf_urlencode() {
  python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

cf_validate_space_key() {
  local key="${1:-}"
  if [[ ! "$key" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
    echo "ERROR: invalid space key '$key' (expected alphanumeric, e.g. estate or CR)" >&2
    return 1
  fi
}

cf_validate_content_id() {
  local id="${1:-}"
  if [[ ! "$id" =~ ^[0-9]+$ ]]; then
    echo "ERROR: invalid content id '$id'" >&2
    return 1
  fi
}

cf_require_confirm_write() {
  if [[ "${CF_CONFIRM_WRITE:-}" == "yes" || "${1:-}" == "yes" ]]; then
    return 0
  fi
  echo "ERROR: write blocked. Pass --confirm-write (single page only)." >&2
  return 1
}

cf_require_confirm_delete() {
  if [[ "${CF_CONFIRM_DELETE:-}" == "yes" || "${1:-}" == "yes" ]]; then
    return 0
  fi
  echo "ERROR: delete blocked. Pass --confirm-delete (explicit delete intent)." >&2
  return 1
}

cf_curl_delete() {
  local url="$1"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -o "$tmp" -w '%{http_code}' \
    -H "Authorization: Bearer ${CF_TOKEN}" \
    -H "Accept: application/json" \
    --connect-timeout 20 --max-time 180 \
    -X DELETE \
    "$url" 2>/dev/null || echo 000)"
  if [[ "$code" != 2* && "$code" != 204 ]]; then
    if [[ -n "$CF_EMAIL" ]]; then
      code="$(curl -sS -o "$tmp" -w '%{http_code}' \
        -u "${CF_EMAIL}:${CF_TOKEN}" \
        -H "Accept: application/json" \
        --connect-timeout 20 --max-time 180 \
        -X DELETE \
        "$url" 2>/dev/null || echo 000)"
    fi
  fi
  CF_LAST_HTTP="$code"
  CF_LAST_BODY="$(cat "$tmp")"
  rm -f "$tmp"
  if [[ "$code" != 2* && "$code" != 204 ]]; then
    echo "ERROR: HTTP $code for DELETE $url" >&2
    echo "$CF_LAST_BODY" | head -c 1200 >&2
    return 1
  fi
}

_cf_curl_json_method() {
  local method="$1"
  local url="$2"
  local json="$3"
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -sS -o "$tmp" -w '%{http_code}' \
    -H "Authorization: Bearer ${CF_TOKEN}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    --connect-timeout 20 --max-time 180 \
    -X "$method" -d "$json" \
    "$url" 2>/dev/null || echo 000)"
  if [[ "$code" != 2* && "$code" != 201 ]]; then
    if [[ -n "$CF_EMAIL" ]]; then
      code="$(curl -sS -o "$tmp" -w '%{http_code}' \
        -u "${CF_EMAIL}:${CF_TOKEN}" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        --connect-timeout 20 --max-time 180 \
        -X "$method" -d "$json" \
        "$url" 2>/dev/null || echo 000)"
    fi
  fi
  CF_LAST_HTTP="$code"
  CF_LAST_BODY="$(cat "$tmp")"
  rm -f "$tmp"
  if [[ "$code" != 2* && "$code" != 201 ]]; then
    echo "ERROR: HTTP $code for $method $url" >&2
    echo "$CF_LAST_BODY" | head -c 1200 >&2
    return 1
  fi
}

cf_curl_post_json() {
  _cf_curl_json_method POST "$1" "$2"
}

cf_curl_put_json() {
  _cf_curl_json_method PUT "$1" "$2"
}

# Resolve page id by space+title or validate explicit id. Sets CF_RESOLVED_PAGE_ID.
cf_resolve_page_id() {
  local page_id="${1:-}"
  local space="${2:-}"
  local title="${3:-}"
  if [[ -n "$page_id" ]]; then
    cf_validate_content_id "$page_id"
    CF_RESOLVED_PAGE_ID="$page_id"
    return 0
  fi
  if [[ -z "$space" || -z "$title" ]]; then
    echo "ERROR: specify page id or space+title" >&2
    return 1
  fi
  cf_validate_space_key "$space"
  local enc_title enc_space
  enc_title="$(cf_urlencode "$title")"
  enc_space="$(cf_urlencode "$space")"
  cf_curl_get "${CF_BASE}/rest/api/content?spaceKey=${enc_space}&title=${enc_title}&expand=version"
  CF_RESOLVED_PAGE_ID="$(python3 -c "import json,sys; r=json.load(sys.stdin).get('results',[]); print(r[0]['id'] if r else '')" <<<"$CF_LAST_BODY")"
  if [[ -z "$CF_RESOLVED_PAGE_ID" ]]; then
    echo "ERROR: page not found: space=$space title=$title" >&2
    return 1
  fi
}

# Read body from --body or --body-file into CF_BODY_STORAGE (Confluence storage HTML).
cf_load_body_storage() {
  local inline="${1:-}"
  local file="${2:-}"
  if [[ -n "$file" ]]; then
    if [[ ! -f "$file" ]]; then
      echo "ERROR: body file not found: $file" >&2
      return 1
    fi
    CF_BODY_STORAGE="$(cat "$file")"
  elif [[ -n "$inline" ]]; then
    CF_BODY_STORAGE="$inline"
  else
    echo "ERROR: provide --body or --body-file" >&2
    return 1
  fi
  if [[ -z "$CF_BODY_STORAGE" ]]; then
    echo "ERROR: body is empty" >&2
    return 1
  fi
}
