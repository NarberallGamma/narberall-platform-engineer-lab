#!/usr/bin/env bash
# Space metadata and page inventory (flat list with ancestors).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cf_lib.sh
source "$SCRIPT_DIR/cf_lib.sh"

SPACE="estate"
LIMIT=500
FORMAT="agent"

usage() {
  cat <<EOF
Usage: cf_space.sh [options]

Options:
  --space KEY     Space key (default: estate, ops docs)
  --limit N       Max pages to fetch (default 500, paginated)
  --format agent|json
  -h              Help

Output: === CF_SPACE ===, === CF_PAGES ===, === CF_TABLE ===
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --space) SPACE="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

cf_validate_space_key "$SPACE"
cf_load_env

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

enc_space="$(cf_urlencode "$SPACE")"
cf_curl_get "${CF_BASE}/rest/api/space/${enc_space}?expand=description.plain,homepage"
printf '%s' "$CF_LAST_BODY" >"$tmpdir/space.json"

printf '[]' >"$tmpdir/pages.json"
start=0
page_size=50
fetched=0

while [[ "$fetched" -lt "$LIMIT" ]]; do
  batch="$page_size"
  if (( fetched + batch > LIMIT )); then
    batch=$((LIMIT - fetched))
  fi
  url="${CF_BASE}/rest/api/content?spaceKey=${enc_space}&type=page&limit=${batch}&start=${start}&expand=ancestors,version"
  cf_curl_get "$url"
  printf '%s' "$CF_LAST_BODY" >"$tmpdir/chunk.json"
  { read -r fetched; read -r chunk_len; } < <(python3 - <<'PY' "$tmpdir/pages.json" "$tmpdir/chunk.json"
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    acc = json.load(f)
with open(sys.argv[2], encoding="utf-8") as f:
    chunk = json.load(f)
results = chunk.get("results", [])
acc.extend(results)
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(acc, f)
print(len(acc))
print(len(results))
PY
)
  chunk_len="${chunk_len:-0}"
  if [[ "$chunk_len" -lt "$batch" ]]; then
    break
  fi
  start=$((start + batch))
done

if [[ "$FORMAT" == "json" ]]; then
  cat "$tmpdir/space.json"
  cat "$tmpdir/pages.json"
  exit 0
fi

python3 - <<'PY' "$tmpdir/space.json" "$tmpdir/pages.json" "$SPACE"
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    space = json.load(f)
with open(sys.argv[2], encoding="utf-8") as f:
    pages = json.load(f)
space_key = sys.argv[3]

def path(p):
    anc = p.get("ancestors") or []
    titles = [a.get("title") for a in anc if a.get("title")]
    titles.append(p.get("title") or "")
    return " / ".join(t for t in titles if t)

rows = []
for p in pages:
    ver = p.get("version") or {}
    rows.append({
        "id": p.get("id"),
        "title": p.get("title"),
        "path": path(p),
        "version": ver.get("number"),
        "webui": (p.get("_links") or {}).get("webui"),
    })
rows.sort(key=lambda r: (r.get("path") or "").lower())

print("=== CF_SPACE ===")
print(json.dumps({
    "key": space.get("key"),
    "name": space.get("name"),
    "type": space.get("type"),
    "homepage_id": (space.get("homepage") or {}).get("id"),
}, ensure_ascii=False, indent=2))
print("=== CF_PAGES ===")
print(json.dumps({
    "space": space_key,
    "count": len(rows),
    "pages": rows,
}, ensure_ascii=False, indent=2))
print("=== CF_TABLE ===")
print("| id | title | version |")
print("| --- | --- | --- |")
for r in rows[:200]:
    title = (r.get("title") or "").replace("|", "\\|")
    print(f"| {r.get('id','')} | {title} | {r.get('version','')} |")
if len(rows) > 200:
    print(f"\n(table truncated to 200 of {len(rows)} pages)")
PY
