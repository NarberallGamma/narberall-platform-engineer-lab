#!/usr/bin/env bash
# Add a comment to an issue (REST API). Body from --body or stdin.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sd_lib.sh
source "$SCRIPT_DIR/sd_lib.sh"

KEY=""
BODY=""
PUBLIC=true
CONFIRM=false

usage() {
  cat <<EOF
Usage: sd_comment.sh ISSUE-KEY --body 'text' --confirm-write
       echo 'text' | sd_comment.sh ISSUE-KEY --confirm-write
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --body) BODY="$2"; shift 2 ;;
    --internal) PUBLIC=false; shift ;;
    --confirm-write) CONFIRM=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown: $1" >&2; exit 1 ;;
    *)
      if [[ -z "$KEY" ]]; then KEY="$1"; else echo "Extra: $1" >&2; exit 1; fi
      shift
      ;;
  esac
done

[[ -n "$KEY" ]] || { usage >&2; exit 1; }
if [[ -z "$BODY" ]]; then
  BODY="$(cat)"
fi
[[ -n "$BODY" ]] || { echo "ERROR: empty comment body" >&2; exit 1; }

sd_validate_issue_key "$KEY"
[[ "$CONFIRM" == true ]] && sd_require_confirm_write yes || sd_require_confirm_write

sd_load_env
export SD_BASE

payload="$(python3 -c "import json,sys; print(json.dumps({'body': sys.argv[1]}))" "$BODY")"
enc_key="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$KEY")"

sd_curl_post_json "${SD_BASE}/rest/api/2/issue/${enc_key}/comment" "$payload"

export SD_LAST_BODY
python3 <<PY
import json, os
data = json.loads(os.environ["SD_LAST_BODY"])
print("=== SD_COMMENT_OK ===")
print(json.dumps({
    "issue": "${KEY}",
    "comment_id": data.get("id"),
    "author": (data.get("author") or {}).get("displayName"),
    "created": data.get("created"),
    "body_preview": (data.get("body") or "")[:200],
}, ensure_ascii=False, indent=2))
PY
