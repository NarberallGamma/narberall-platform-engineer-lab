#!/usr/bin/env bash
# Create one Confluence page in any accessible space.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cf_lib.sh
source "$SCRIPT_DIR/cf_lib.sh"

SPACE=""
TITLE=""
BODY=""
BODY_FILE=""
PARENT_ID=""
CONFIRM=""

usage() {
  cat <<EOF
Usage: cf_page_create.sh --space KEY --title "Title" (--body HTML | --body-file PATH) --confirm-write

Options:
  --space KEY        Target space key (e.g. estate, ITD)
  --title TEXT       New page title (single page)
  --body HTML        body.storage HTML value
  --body-file PATH   Read body.storage from file (preferred for long content)
  --parent-id ID     Optional parent page id (creates child page)
  --confirm-write    Required to create

Output: === CF_PAGE_CREATE_OK ===
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --space) SPACE="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --body) BODY="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --parent-id) PARENT_ID="$2"; shift 2 ;;
    --confirm-write) CONFIRM="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

cf_require_confirm_write "$CONFIRM"
[[ -n "$SPACE" && -n "$TITLE" ]] || { echo "ERROR: --space and --title required" >&2; exit 1; }
cf_validate_space_key "$SPACE"
[[ -n "$PARENT_ID" ]] && cf_validate_content_id "$PARENT_ID"

cf_load_env
cf_load_body_storage "$BODY" "$BODY_FILE"
export CF_BODY_STORAGE

payload="$(python3 - <<'PY' "$SPACE" "$TITLE" "$PARENT_ID"
import json, os, sys
space, title, parent = sys.argv[1], sys.argv[2], sys.argv[3]
body = os.environ["CF_BODY_STORAGE"]
doc = {
    "type": "page",
    "title": title,
    "space": {"key": space},
    "body": {
        "storage": {
            "value": body,
            "representation": "storage",
        }
    },
}
if parent:
    doc["ancestors"] = [{"id": parent}]
print(json.dumps(doc, ensure_ascii=False))
PY
)"

cf_curl_post_json "${CF_BASE}/rest/api/content" "$payload"

python3 - <<'PY' "$CF_LAST_BODY" "$SPACE"
import json, sys
page = json.loads(sys.argv[1])
space = sys.argv[2]
sp = page.get("space") or {}
ver = page.get("version") or {}
print("=== CF_PAGE_CREATE_OK ===")
print(json.dumps({
    "id": page.get("id"),
    "title": page.get("title"),
    "space": sp.get("key") or space,
    "version": ver.get("number"),
    "webui": (page.get("_links") or {}).get("webui"),
    "base": page.get("_links", {}).get("base"),
}, ensure_ascii=False, indent=2))
PY
