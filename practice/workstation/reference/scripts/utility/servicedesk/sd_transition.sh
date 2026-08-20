#!/usr/bin/env bash
# List or execute workflow transitions (Jira REST). REST token + email required for apply.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sd_lib.sh
source "$SCRIPT_DIR/sd_lib.sh"

KEY=""
LIST=false
TRANS_ID=""
TRANS_NAME=""
COMMENT=""
CONFIRM=false

usage() {
  cat <<EOF
Usage:
  sd_transition.sh ISSUE-KEY --list
  sd_transition.sh ISSUE-KEY --id TRANSITION_ID [--comment 'text'] --confirm-write
  sd_transition.sh ISSUE-KEY --name 'Transition name' [--comment 'text'] --confirm-write

Name match: exact (case-insensitive), then substring.
Apply requires --confirm-write (single issue only).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list) LIST=true; shift ;;
    --id) TRANS_ID="$2"; shift 2 ;;
    --name) TRANS_NAME="$2"; shift 2 ;;
    --comment) COMMENT="$2"; shift 2 ;;
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

sd_validate_issue_key "$KEY"

sd_load_env
export SD_BASE

enc_key="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$KEY")"
trans_url="${SD_BASE}/rest/api/2/issue/${enc_key}/transitions?expand=transitions.fields"

sd_curl_get "$trans_url"
trans_json="$SD_LAST_BODY"

if [[ "$LIST" == true ]]; then
  export TJ="$trans_json" KEY="$KEY"
  echo "=== SD_TRANSITIONS ==="
  python3 <<'PY'
import json, os
d = json.loads(os.environ["TJ"])
rows = []
for t in d.get("transitions", []):
    to = (t.get("to") or {})
    rows.append({
        "id": t.get("id"),
        "name": t.get("name"),
        "to_status": to.get("name"),
        "to_status_id": to.get("id"),
    })
print(json.dumps({"issue": os.environ["KEY"], "transitions": rows}, ensure_ascii=False, indent=2))
print()
print("=== SD_TRANSITIONS_TABLE ===")
print("| id | name | to_status |")
print("|----|------|-----------|")
for r in rows:
    print(f"| {r['id']} | {r['name']} | {r['to_status']} |")
PY
  exit 0
fi

export TJ="$trans_json" KEY="$KEY"

if [[ -n "$TRANS_ID" ]]; then
  tid="$TRANS_ID"
elif [[ -n "$TRANS_NAME" ]]; then
  export TN="$TRANS_NAME"
  tid="$(python3 <<'PY'
import json, os
d = json.loads(os.environ["TJ"])
name = os.environ["TN"].strip().lower()
found = None
for t in d.get("transitions", []):
    n = (t.get("name") or "").lower()
    if n == name:
        found = t["id"]
        break
if not found:
    for t in d.get("transitions", []):
        n = (t.get("name") or "").lower()
        if name in n or n in name:
            found = t["id"]
            break
if found:
    print(found)
PY
)"
fi

[[ -n "$tid" ]] || {
  echo "ERROR: specify --id or --name (use --list to see transitions)" >&2
  exit 1
}

[[ "$CONFIRM" == true ]] && sd_require_confirm_write yes || sd_require_confirm_write

if [[ -z "$SD_REST" || -z "$SD_EMAIL" ]]; then
  echo "ERROR: transition requires SERVICEDESK_CURSOR_REST_TOKEN and SERVICEDESK_USER_EMAIL" >&2
  exit 1
fi

export TID="$tid" COMMENT="$COMMENT"

payload="$(python3 <<'PY'
import json, os
tid = os.environ["TID"]
comment = os.environ.get("COMMENT", "")
body = {"transition": {"id": str(tid)}}
if comment:
    body["update"] = {"comment": [{"add": {"body": comment}}]}
print(json.dumps(body, ensure_ascii=False))
PY
)"

post_url="${SD_BASE}/rest/api/2/issue/${enc_key}/transitions"
sd_curl_post_json "$post_url" "$payload"

# Verify new status
sd_curl_get "${SD_BASE}/rest/api/2/issue/${enc_key}?fields=status,summary"
export VERIFY="$SD_LAST_BODY"
echo "=== SD_TRANSITION_OK ==="
python3 <<'PY'
import json, os
issue = json.loads(os.environ["VERIFY"])
st = issue.get("fields", {}).get("status", {})
print(json.dumps({
    "issue": os.environ["KEY"],
    "transition_id": os.environ["TID"],
    "status": st.get("name"),
    "status_id": st.get("id"),
    "comment_added": bool(os.environ.get("COMMENT")),
}, ensure_ascii=False, indent=2))
PY
