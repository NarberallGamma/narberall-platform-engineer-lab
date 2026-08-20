#!/usr/bin/env bash
# Create one INFRA issue: Request (default) or Sub-task.
# Defaults: org estate (customfield_12604), request type 433 when using sdapi.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sd_lib.sh
source "$SCRIPT_DIR/sd_lib.sh"

SUMMARY=""
DESCRIPTION=""
ORG=""
ORG_KEY=""
REQUEST_TYPE_ID=""
METHOD="jira"
CONFIRM=false
ASSIGNEE=""
REPORTER=""
EPIC=""
PARENT=""
ISSUETYPE="Request"

usage() {
  cat <<EOF
Usage: sd_create.sh --summary 'Title' [--description 'text'] [--confirm-create]

Defaults: project INFRA, issuetype Request, client organisation estate (customfield_12604).

Optional:
  --org 'ORG LABEL'       display label (default: SD_ORG_LABEL; informational)
  --org-key ORG-0001      Insight object key for Client organisation (default: SD_ORG_KEY)
  --assignee USERNAME     Jira username (e.g. winuser)
  --reporter USERNAME     Jira username (e.g. jira-user); needs Modify Reporter
  --epic INFRA-215        Epic Link (customfield_13109); ignored for Sub-task
  --parent INFRA-xxx      parent Request key → creates Sub-task
  --issuetype NAME        Request (default) or Sub-task
  --request-type-id N     servicedeskapi only (default 433)
  --method jira|sdapi     jira = REST /issue; sdapi = portal (Request only)
  --confirm-create        required to create (one issue only)

No bulk create. No JQL.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary) SUMMARY="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --org) ORG="$2"; shift 2 ;;
    --org-key) ORG_KEY="$2"; shift 2 ;;
    --assignee) ASSIGNEE="$2"; shift 2 ;;
    --reporter) REPORTER="$2"; shift 2 ;;
    --epic) EPIC="$2"; shift 2 ;;
    --parent) PARENT="$2"; shift 2 ;;
    --issuetype) ISSUETYPE="$2"; shift 2 ;;
    --request-type-id) REQUEST_TYPE_ID="$2"; shift 2 ;;
    --method) METHOD="$2"; shift 2 ;;
    --confirm-create) CONFIRM=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown: $1" >&2; exit 1 ;;
    *) echo "Unexpected: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$SUMMARY" ]] || { usage >&2; exit 1; }
[[ "$CONFIRM" == true ]] && sd_require_confirm_create yes || sd_require_confirm_create

DESCRIPTION="${DESCRIPTION:-$SUMMARY}"
ORG="${ORG:-$SD_ORG_LABEL}"
ORG_KEY="${ORG_KEY:-$SD_ORG_KEY}"
REQUEST_TYPE_ID="${REQUEST_TYPE_ID:-$SD_INFRA_REQUEST_TYPE_ID}"

if [[ -n "$PARENT" ]]; then
  sd_validate_issue_key "$PARENT"
  ISSUETYPE="Sub-task"
fi
if [[ -n "$EPIC" ]]; then
  sd_validate_issue_key "$EPIC"
fi
if [[ "$ISSUETYPE" == "Sub-task" && -z "$PARENT" ]]; then
  echo "ERROR: Sub-task requires --parent PARENT-KEY" >&2
  exit 1
fi
if [[ "$METHOD" == "sdapi" && "$ISSUETYPE" != "Request" ]]; then
  echo "ERROR: --method sdapi only supports issuetype Request; use jira for Sub-task" >&2
  exit 1
fi

sd_load_env
if [[ -z "$SD_REST" || -z "$SD_EMAIL" ]]; then
  echo "ERROR: create requires SERVICEDESK_CURSOR_REST_TOKEN and SERVICEDESK_USER_EMAIL" >&2
  exit 1
fi

export SD_BASE SUMMARY DESCRIPTION ORG ORG_KEY REQUEST_TYPE_ID METHOD
export ASSIGNEE REPORTER EPIC PARENT ISSUETYPE
METHOD="${METHOD:-jira}"
export METHOD

issue_key=""
issue_id=""

if [[ "$METHOD" == "sdapi" ]]; then
  export SD_INFRA_SERVICE_DESK_ID
  payload="$(python3 <<'PY'
import json, os
body = {
    "serviceDeskId": os.environ.get("SD_INFRA_SERVICE_DESK_ID", "30"),
    "requestTypeId": os.environ["REQUEST_TYPE_ID"],
    "requestFieldValues": {
        "summary": os.environ["SUMMARY"],
        "description": os.environ["DESCRIPTION"],
    },
}
print(json.dumps(body, ensure_ascii=False))
PY
)"
  sd_curl_post_json "${SD_BASE}/rest/servicedeskapi/request" "$payload"
  export SD_LAST_BODY
  eval "$(python3 <<'PY'
import json, os
d = json.loads(os.environ["SD_LAST_BODY"])
print(f'issue_key="{d.get("issueKey","")}"')
print(f'issue_id="{d.get("issueId","")}"')
PY
)"
  # Post-create field updates (org / epic / assignee / reporter)
  if [[ -n "$issue_key" ]]; then
    enc_key="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$issue_key")"
    put_payload="$(python3 <<'PY'
import json, os
fields = {}
org_key = os.environ.get("ORG_KEY", "").strip()
if org_key:
    fields["customfield_12604"] = [{"key": org_key}]
epic = os.environ.get("EPIC", "").strip()
if epic:
    fields["customfield_13109"] = epic
assignee = os.environ.get("ASSIGNEE", "").strip()
if assignee:
    fields["assignee"] = {"name": assignee}
reporter = os.environ.get("REPORTER", "").strip()
if reporter:
    fields["reporter"] = {"name": reporter}
print(json.dumps({"fields": fields}, ensure_ascii=False) if fields else "")
PY
)"
    if [[ -n "$put_payload" ]]; then
      sd_curl_put_json "${SD_BASE}/rest/api/2/issue/${enc_key}" "$put_payload"
    fi
  fi
else
  payload="$(python3 <<'PY'
import json, os
fields = {
    "project": {"key": "INFRA"},
    "issuetype": {"name": os.environ.get("ISSUETYPE", "Request")},
    "summary": os.environ["SUMMARY"],
    "description": os.environ["DESCRIPTION"],
}
parent = os.environ.get("PARENT", "").strip()
if parent:
    fields["parent"] = {"key": parent}
else:
    org_key = os.environ.get("ORG_KEY", "").strip()
    if org_key:
        fields["customfield_12604"] = [{"key": org_key}]
    epic = os.environ.get("EPIC", "").strip()
    if epic:
        fields["customfield_13109"] = epic
assignee = os.environ.get("ASSIGNEE", "").strip()
if assignee:
    fields["assignee"] = {"name": assignee}
reporter = os.environ.get("REPORTER", "").strip()
if reporter:
    fields["reporter"] = {"name": reporter}
print(json.dumps({"fields": fields}, ensure_ascii=False))
PY
)"
  sd_curl_post_json "${SD_BASE}/rest/api/2/issue" "$payload"
  export SD_LAST_BODY
  eval "$(python3 <<'PY'
import json, os
d = json.loads(os.environ["SD_LAST_BODY"])
print(f'issue_key="{d.get("key","")}"')
print(f'issue_id="{d.get("id","")}"')
PY
)"
fi

[[ -n "$issue_key" ]] || { echo "ERROR: create response missing issue key" >&2; exit 1; }

enc_key="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$issue_key")"
sd_curl_get "${SD_BASE}/rest/api/2/issue/${enc_key}?fields=summary,status,issuetype,assignee,reporter,parent,customfield_12604,customfield_13109"
export VERIFY="$SD_LAST_BODY" KEY="$issue_key" ID="$issue_id" ORG="$ORG"

echo "=== SD_CREATE_OK ==="
python3 <<'PY'
import json, os
issue = json.loads(os.environ["VERIFY"])
fields = issue.get("fields") or {}
org = fields.get("customfield_12604")
if isinstance(org, list):
    org_preview = [(x.get("value") if isinstance(x, dict) else x) for x in org]
elif isinstance(org, dict):
    org_preview = org.get("value") or org
else:
    org_preview = org
asn = fields.get("assignee") or {}
rep = fields.get("reporter") or {}
parent = fields.get("parent") or {}
print(json.dumps({
    "issue": os.environ["KEY"],
    "issue_id": os.environ.get("ID", ""),
    "summary": fields.get("summary"),
    "status": (fields.get("status") or {}).get("name"),
    "issuetype": (fields.get("issuetype") or {}).get("name"),
    "organisation": org_preview,
    "epic": fields.get("customfield_13109"),
    "parent": parent.get("key"),
    "assignee": asn.get("displayName") or asn.get("name"),
    "assignee_name": asn.get("name"),
    "reporter": rep.get("displayName") or rep.get("name"),
    "reporter_name": rep.get("name"),
    "method": os.environ.get("METHOD", "jira"),
    "url": f"{os.environ.get('SD_BASE','').rstrip('/')}/browse/{os.environ['KEY']}",
}, ensure_ascii=False, indent=2))
PY
