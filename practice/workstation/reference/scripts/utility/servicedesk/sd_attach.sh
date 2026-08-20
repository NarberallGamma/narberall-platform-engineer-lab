#!/usr/bin/env bash
# Upload one or more files as issue attachments (Jira REST).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sd_lib.sh
source "$SCRIPT_DIR/sd_lib.sh"

KEY=""
FILES=()
CONFIRM=false

usage() {
  echo "Usage: sd_attach.sh ISSUE-KEY FILE [FILE ...] --confirm-write"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --confirm-write) CONFIRM=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown: $1" >&2; exit 1 ;;
    *)
      if [[ -z "$KEY" ]]; then KEY="$1"; else FILES+=("$1"); fi
      shift
      ;;
  esac
done

[[ -n "$KEY" && ${#FILES[@]} -gt 0 ]] || { usage >&2; exit 1; }

sd_validate_issue_key "$KEY"
[[ "$CONFIRM" == true ]] && sd_require_confirm_write yes || sd_require_confirm_write

sd_load_env
if [[ -z "$SD_REST" || -z "$SD_EMAIL" ]]; then
  echo "ERROR: upload requires SERVICEDESK_CURSOR_REST_TOKEN and SERVICEDESK_USER_EMAIL" >&2
  exit 1
fi

enc_key="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$KEY")"
url="${SD_BASE}/rest/api/2/issue/${enc_key}/attachments"

echo "=== SD_ATTACH ==="
for f in "${FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: not a file: $f" >&2
    exit 1
  fi
  base="$(basename "$f")"
  tmp="$(mktemp)"
  code="$(curl -sS -o "$tmp" -w '%{http_code}' \
    -u "${SD_EMAIL}:${SD_REST}" \
    -H "X-Atlassian-Token: no-check" \
    -F "file=@${f};filename=${base}" \
    --connect-timeout 30 --max-time 300 \
    "$url" || echo 000)"
  body="$(head -c 1500 "$tmp")"
  rm -f "$tmp"
  if [[ "$code" != 2* ]]; then
    echo "FAIL file=$base http=$code" >&2
    echo "$body" >&2
    exit 1
  fi
  echo "OK file=$base http=$code"
  python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps({'filename': d[0].get('filename'), 'id': d[0].get('id'), 'size': d[0].get('size')}, ensure_ascii=False))" <<<"$body" 2>/dev/null || echo "$body"
done
echo "=== SD_ATTACH_DONE issue=$KEY ==="
