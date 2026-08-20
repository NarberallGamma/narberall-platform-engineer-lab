#!/usr/bin/env bash
# Assign issue to a Jira user (username). REST token + email required.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sd_lib.sh
source "$SCRIPT_DIR/sd_lib.sh"

KEY=""
ASSIGNEE=""
CONFIRM=false

usage() {
  cat <<EOF
Usage: sd_assign.sh ISSUE-KEY --assignee USERNAME --confirm-write

Assigns exactly one issue. No bulk assign.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --assignee) ASSIGNEE="$2"; shift 2 ;;
    --confirm-write) CONFIRM=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown: $1" >&2; exit 1 ;;
    *)
      if [[ -z "$KEY" ]]; then KEY="$1"; else echo "Extra: $1" >&2; exit 1; fi
      shift
      ;;
  esac
done

[[ -n "$KEY" && -n "$ASSIGNEE" ]] || { usage >&2; exit 1; }
sd_validate_issue_key "$KEY"
[[ "$CONFIRM" == true ]] && sd_require_confirm_write yes || sd_require_confirm_write

sd_load_env
if [[ -z "$SD_REST" || -z "$SD_EMAIL" ]]; then
  echo "ERROR: assign requires SERVICEDESK_CURSOR_REST_TOKEN and SERVICEDESK_USER_EMAIL" >&2
  exit 1
fi

export SD_BASE
enc_key="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$KEY")"
payload="$(python3 -c "import json,sys; print(json.dumps({'fields': {'assignee': {'name': sys.argv[1]}}}))" "$ASSIGNEE")"

sd_curl_put_json "${SD_BASE}/rest/api/2/issue/${enc_key}" "$payload"

sd_curl_get "${SD_BASE}/rest/api/2/issue/${enc_key}?fields=assignee,status,summary"
export VERIFY="$SD_LAST_BODY" KEY="$KEY" ASSIGNEE="$ASSIGNEE"
echo "=== SD_ASSIGN_OK ==="
python3 <<'PY'
import json, os
issue = json.loads(os.environ["VERIFY"])
a = (issue.get("fields") or {}).get("assignee") or {}
st = (issue.get("fields") or {}).get("status") or {}
print(json.dumps({
    "issue": os.environ["KEY"],
    "assignee_requested": os.environ["ASSIGNEE"],
    "assignee_name": a.get("name"),
    "assignee_display": a.get("displayName"),
    "status": st.get("name"),
    "summary": (issue.get("fields") or {}).get("summary"),
}, ensure_ascii=False, indent=2))
PY
