#!/usr/bin/env bash
# Update one Confluence page (body and optional title).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cf_lib.sh
source "$SCRIPT_DIR/cf_lib.sh"

PAGE_ID=""
SPACE=""
LOOKUP_TITLE=""
NEW_TITLE=""
BODY=""
BODY_FILE=""
CONFIRM=""

usage() {
  cat <<EOF
Usage: cf_page_update.sh (--id ID | --space KEY --title "Title") (--body HTML | --body-file PATH) --confirm-write

Options:
  --id ID            Page content id (preferred)
  --space KEY        Space key with --title lookup
  --title TEXT       Existing page title for lookup
  --new-title TEXT   Optional rename on update
  --body HTML        New body.storage HTML
  --body-file PATH   Read body from file
  --confirm-write    Required to update

Output: === CF_PAGE_UPDATE_OK ===
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) PAGE_ID="$2"; shift 2 ;;
    --space) SPACE="$2"; shift 2 ;;
    --title) LOOKUP_TITLE="$2"; shift 2 ;;
    --new-title) NEW_TITLE="$2"; shift 2 ;;
    --body) BODY="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --confirm-write) CONFIRM="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

cf_require_confirm_write "$CONFIRM"
cf_load_env
cf_resolve_page_id "$PAGE_ID" "$SPACE" "$LOOKUP_TITLE"
PAGE_ID="$CF_RESOLVED_PAGE_ID"
cf_load_body_storage "$BODY" "$BODY_FILE"
export CF_BODY_STORAGE

cf_curl_get "${CF_BASE}/rest/api/content/${PAGE_ID}?expand=version,space"
current="$CF_LAST_BODY"

payload="$(python3 - <<'PY' "$current" "$NEW_TITLE"
import json, os, sys
current = json.loads(sys.argv[1])
new_title = sys.argv[2]
body = os.environ["CF_BODY_STORAGE"]
title = new_title or current.get("title") or ""
ver = (current.get("version") or {}).get("number")
if not ver:
    raise SystemExit("ERROR: could not read current page version")
doc = {
    "id": current.get("id"),
    "type": "page",
    "title": title,
    "version": {"number": ver + 1},
    "body": {
        "storage": {
            "value": body,
            "representation": "storage",
        }
    },
}
print(json.dumps(doc, ensure_ascii=False))
PY
)"

cf_curl_put_json "${CF_BASE}/rest/api/content/${PAGE_ID}" "$payload"

python3 - <<'PY' "$CF_LAST_BODY"
import json, sys
page = json.loads(sys.argv[1])
sp = page.get("space") or {}
ver = page.get("version") or {}
print("=== CF_PAGE_UPDATE_OK ===")
print(json.dumps({
    "id": page.get("id"),
    "title": page.get("title"),
    "space": sp.get("key"),
    "version": ver.get("number"),
    "webui": (page.get("_links") or {}).get("webui"),
}, ensure_ascii=False, indent=2))
PY
