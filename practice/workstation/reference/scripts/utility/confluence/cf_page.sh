#!/usr/bin/env bash
# Fetch one page by id or by space+title.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cf_lib.sh
source "$SCRIPT_DIR/cf_lib.sh"

PAGE_ID=""
SPACE=""
TITLE=""
BODY_CHARS=8000

usage() {
  cat <<EOF
Usage: cf_page.sh (--id ID | --space KEY --title "Title") [options]

Options:
  --id ID           Content id
  --space KEY       Space key (with --title)
  --title TEXT      Page title exact match (with --space)
  --body-chars N    Truncate body.storage to N chars (default 8000, 0=omit body)
  -h                Help

Output: === CF_PAGE ===
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) PAGE_ID="$2"; shift 2 ;;
    --space) SPACE="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --body-chars) BODY_CHARS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

cf_load_env

if [[ -n "$PAGE_ID" ]]; then
  cf_validate_content_id "$PAGE_ID"
elif [[ -n "$SPACE" && -n "$TITLE" ]]; then
  cf_validate_space_key "$SPACE"
  enc_title="$(cf_urlencode "$TITLE")"
  enc_space="$(cf_urlencode "$SPACE")"
  cf_curl_get "${CF_BASE}/rest/api/content?spaceKey=${enc_space}&title=${enc_title}&expand=version"
  PAGE_ID="$(python3 -c "import json,sys; r=json.load(sys.stdin).get('results',[]); print(r[0]['id'] if r else '')" <<<"$CF_LAST_BODY")"
  if [[ -z "$PAGE_ID" ]]; then
    echo "ERROR: page not found: space=$SPACE title=$TITLE" >&2
    exit 1
  fi
else
  echo "ERROR: specify --id or --space + --title" >&2
  usage >&2
  exit 1
fi

expand="space,version,ancestors"
if [[ "$BODY_CHARS" != "0" ]]; then
  expand+=",body.storage"
fi
enc_expand="$(cf_urlencode "$expand")"
cf_curl_get "${CF_BASE}/rest/api/content/${PAGE_ID}?expand=${enc_expand}"

python3 - <<'PY' "$CF_LAST_BODY" "$BODY_CHARS"
import json, sys
page = json.loads(sys.argv[1])
body_chars = int(sys.argv[2])
sp = page.get("space") or {}
ver = page.get("version") or {}
body = (((page.get("body") or {}).get("storage") or {}).get("value")) or ""
if body_chars and len(body) > body_chars:
    body = body[:body_chars] + "\n... [truncated]"
out = {
    "id": page.get("id"),
    "title": page.get("title"),
    "space": sp.get("key"),
    "type": page.get("type"),
    "version": ver.get("number"),
    "webui": (page.get("_links") or {}).get("webui"),
    "ancestors": [{"id": a.get("id"), "title": a.get("title")} for a in (page.get("ancestors") or [])],
}
if body_chars:
    out["body_storage"] = body
print("=== CF_PAGE ===")
print(json.dumps(out, ensure_ascii=False, indent=2))
PY
