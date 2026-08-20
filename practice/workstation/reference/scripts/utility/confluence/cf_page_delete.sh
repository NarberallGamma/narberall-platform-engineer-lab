#!/usr/bin/env bash
# Delete one Confluence page (trash). Strong safety checks before DELETE.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cf_lib.sh
source "$SCRIPT_DIR/cf_lib.sh"

PAGE_ID=""
EXPECT_TITLE=""
EXPECT_SPACE=""
CONFIRM_WRITE=""
CONFIRM_DELETE=""
DRY_RUN=""

usage() {
  cat <<EOF
Usage: cf_page_delete.sh --id PAGE_ID --expect-title "Exact title" --confirm-write --confirm-delete [options]

Required safety:
  --id ID              Page content id (numeric only, one page)
  --expect-title TEXT  Must match current page title exactly (prevents wrong id)
  --confirm-write      Required mutating guard
  --confirm-delete     Explicit delete intent (second guard)

Optional:
  --expect-space KEY   Must match page space key if set
  --dry-run            Preview only, never DELETE (overrides delete even with confirms)

Blocks (no override):
  - space homepage
  - page with child pages (delete children first)

Output: === CF_PAGE_DELETE_PREVIEW ===, === CF_PAGE_DELETE_OK === or dry-run note
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) PAGE_ID="$2"; shift 2 ;;
    --expect-title) EXPECT_TITLE="$2"; shift 2 ;;
    --expect-space) EXPECT_SPACE="$2"; shift 2 ;;
    --confirm-write) CONFIRM_WRITE="yes"; shift ;;
    --confirm-delete) CONFIRM_DELETE="yes"; shift ;;
    --dry-run) DRY_RUN="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[[ -n "$PAGE_ID" ]] || { echo "ERROR: --id is required (no delete by title lookup)" >&2; exit 1; }
[[ -n "$EXPECT_TITLE" ]] || { echo "ERROR: --expect-title is required (exact match guard)" >&2; exit 1; }
cf_validate_content_id "$PAGE_ID"
[[ -n "$EXPECT_SPACE" ]] && cf_validate_space_key "$EXPECT_SPACE"

cf_load_env

enc_expand="$(cf_urlencode "space,version,ancestors")"
cf_curl_get "${CF_BASE}/rest/api/content/${PAGE_ID}?expand=${enc_expand}"
page_json="$CF_LAST_BODY"

cf_curl_get "${CF_BASE}/rest/api/content/${PAGE_ID}/child/page?limit=1"
child_json="$CF_LAST_BODY"

python3 - <<'PY' "$page_json" "$child_json" "$EXPECT_TITLE" "$EXPECT_SPACE" "$PAGE_ID"
import json, sys
page = json.loads(sys.argv[1])
child = json.loads(sys.argv[2])
expect_title = sys.argv[3]
expect_space = sys.argv[4] or ""
page_id = sys.argv[5]

title = page.get("title") or ""
sp = page.get("space") or {}
space_key = sp.get("key") or ""
ver = page.get("version") or {}
ancestors = page.get("ancestors") or []
children = child.get("results") or []
child_count = child.get("size", len(children))

if title != expect_title:
    raise SystemExit(
        f"ERROR: title mismatch: page id={page_id} title={title!r} != expect-title={expect_title!r}"
    )
if expect_space and space_key != expect_space:
    raise SystemExit(
        f"ERROR: space mismatch: page space={space_key!r} != expect-space={expect_space!r}"
    )
if children or (isinstance(child_count, int) and child_count > 0):
    names = [c.get("title") for c in children[:3]]
    raise SystemExit(
        "ERROR: page has child pages; delete or move children first. "
        f"child_count>={child_count}, sample={names}"
    )

path_titles = [a.get("title") for a in ancestors if a.get("title")]
path_titles.append(title)
preview = {
    "id": page.get("id"),
    "title": title,
    "space": space_key,
    "version": ver.get("number"),
    "path": " / ".join(t for t in path_titles if t),
    "webui": (page.get("_links") or {}).get("webui"),
    "child_count": child_count,
}
print("=== CF_PAGE_DELETE_PREVIEW ===")
print(json.dumps(preview, ensure_ascii=False, indent=2))
PY

preview_space="$(
  python3 -c "import json,sys; print(json.load(sys.stdin).get('space',{}).get('key',''))" <<<"$page_json"
)"

if [[ -n "$preview_space" ]]; then
  enc_space="$(cf_urlencode "$preview_space")"
  cf_curl_get "${CF_BASE}/rest/api/space/${enc_space}?expand=homepage"
  homepage_id="$(python3 -c "import json,sys; h=json.load(sys.stdin).get('homepage') or {}; print(h.get('id',''))" <<<"$CF_LAST_BODY")"
  if [[ -n "$homepage_id" && "$homepage_id" == "$PAGE_ID" ]]; then
    echo "ERROR: refusing to delete space homepage id=$PAGE_ID space=$preview_space" >&2
    exit 1
  fi
fi

if [[ "$DRY_RUN" == "yes" ]]; then
  echo "=== CF_PAGE_DELETE_DRY_RUN ==="
  echo "dry_run=yes delete_skipped=1 page_id=$PAGE_ID"
  exit 0
fi

cf_require_confirm_write "$CONFIRM_WRITE"
cf_require_confirm_delete "$CONFIRM_DELETE"

cf_curl_delete "${CF_BASE}/rest/api/content/${PAGE_ID}?status=current"

echo "=== CF_PAGE_DELETE_OK ==="
python3 - <<'PY' "$PAGE_ID" "$EXPECT_TITLE" "$preview_space"
import json, sys
page_id, title, space = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({
    "deleted_id": page_id,
    "title": title,
    "space": space,
    "note": "Page moved to trash (Confluence default for DELETE).",
}, ensure_ascii=False, indent=2))
PY
