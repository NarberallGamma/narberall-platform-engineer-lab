#!/usr/bin/env bash
# Verify Confluence PAT and list accessible spaces (summary).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cf_lib.sh
source "$SCRIPT_DIR/cf_lib.sh"

LIMIT=100

usage() {
  cat <<EOF
Usage: cf_verify.sh [--limit N]

Checks CONFLUENCE_CURSOR_TOKEN against CONFLUENCE_BASE_URL.
Output markers: === CF_VERIFY_OK ===, === CF_SPACES ===
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit) LIMIT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

cf_load_env

cf_curl_get "${CF_BASE}/rest/api/user/current"
user_json="$CF_LAST_BODY"

cf_curl_get "${CF_BASE}/rest/api/space?limit=${LIMIT}&expand=description.plain"
spaces_json="$CF_LAST_BODY"

python3 - <<'PY' "$user_json" "$spaces_json" "$CF_BASE"
import json, sys
user = json.loads(sys.argv[1])
spaces = json.loads(sys.argv[2])
base = sys.argv[3]
print("=== CF_VERIFY_OK ===")
print(json.dumps({
    "base_url": base,
    "user": {
        "username": user.get("username"),
        "displayName": user.get("displayName"),
        "type": user.get("type"),
    },
    "spaces_total": spaces.get("size", len(spaces.get("results", []))),
}, ensure_ascii=False, indent=2))
print("=== CF_SPACES ===")
rows = []
for s in spaces.get("results", []):
    rows.append({
        "key": s.get("key"),
        "name": s.get("name"),
        "type": s.get("type"),
    })
rows.sort(key=lambda r: (r.get("key") or ""))
print(json.dumps({"spaces": rows}, ensure_ascii=False, indent=2))
print("=== CF_TABLE ===")
print("| key | name | type |")
print("| --- | --- | --- |")
for r in rows:
    name = (r.get("name") or "").replace("|", "\\|")
    print(f"| {r.get('key','')} | {name} | {r.get('type','')} |")
PY
