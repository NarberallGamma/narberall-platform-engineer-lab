#!/usr/bin/env bash
# CQL search in Confluence.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cf_lib.sh
source "$SCRIPT_DIR/cf_lib.sh"

CQL=""
SPACE=""
TEXT=""
LIMIT=50

usage() {
  cat <<EOF
Usage: cf_search.sh [options]

Options:
  --cql QUERY       Full CQL query (overrides --space/--text builder)
  --space KEY       AND space = KEY
  --text FRAGMENT   AND text ~ "fragment"
  --limit N         Max results (default 50)
  -h                Help

Output: === CF_SEARCH ===, === CF_TABLE ===
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cql) CQL="$2"; shift 2 ;;
    --space) SPACE="$2"; shift 2 ;;
    --text) TEXT="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

cf_load_env

if [[ -z "$CQL" ]]; then
  parts=("type=page")
  if [[ -n "$SPACE" ]]; then
    cf_validate_space_key "$SPACE"
    parts+=("space=${SPACE}")
  fi
  if [[ -n "$TEXT" ]]; then
    esc="${TEXT//\"/\\\"}"
    parts+=("text ~ \"${esc}\"")
  fi
  CQL="${parts[0]}"
  for ((i = 1; i < ${#parts[@]}; i++)); do
    CQL+=" AND ${parts[$i]}"
  done
fi

enc_cql="$(cf_urlencode "$CQL")"
cf_curl_get "${CF_BASE}/rest/api/content/search?cql=${enc_cql}&limit=${LIMIT}&expand=space,version"

python3 - <<'PY' "$CF_LAST_BODY" "$CQL"
import json, sys
data = json.loads(sys.argv[1])
cql = sys.argv[2]
rows = []
for r in data.get("results", []):
    sp = r.get("space") or {}
    ver = r.get("version") or {}
    rows.append({
        "id": r.get("id"),
        "title": r.get("title"),
        "space": sp.get("key"),
        "type": r.get("type"),
        "version": ver.get("number"),
        "webui": (r.get("_links") or {}).get("webui"),
    })
print("=== CF_SEARCH ===")
print(json.dumps({"cql": cql, "size": data.get("size", len(rows)), "results": rows}, ensure_ascii=False, indent=2))
print("=== CF_TABLE ===")
print("| id | space | title | version |")
print("| --- | --- | --- | --- |")
for r in rows:
    title = (r.get("title") or "").replace("|", "\\|")
    print(f"| {r.get('id','')} | {r.get('space','')} | {title} | {r.get('version','')} |")
PY
