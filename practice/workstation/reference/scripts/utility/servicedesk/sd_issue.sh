#!/usr/bin/env bash
# Full issue view: fields, description, comments, attachment metadata; optional download.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sd_lib.sh
source "$SCRIPT_DIR/sd_lib.sh"

KEY=""
DOWNLOAD_ATTACH=false
OUT_DIR=""

usage() {
  echo "Usage: sd_issue.sh ISSUE-KEY [--download-attachments] [--out-dir PATH]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --download-attachments) DOWNLOAD_ATTACH=true; shift ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown: $1" >&2; exit 1 ;;
    *)
      if [[ -z "$KEY" ]]; then KEY="$1"; else echo "Extra arg: $1" >&2; exit 1; fi
      shift
      ;;
  esac
done

[[ -n "$KEY" ]] || { usage >&2; exit 1; }

sd_load_env
export SD_BASE

enc_key="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$KEY")"
sd_curl_get "${SD_BASE}/rest/api/2/issue/${enc_key}?expand=renderedFields,names"
issue_json="$SD_LAST_BODY"

sd_curl_get "${SD_BASE}/rest/api/2/issue/${enc_key}/comment?maxResults=100"
comments_json="$SD_LAST_BODY"

ATTACH_DIR=""
if [[ "$DOWNLOAD_ATTACH" == true ]]; then
  ATTACH_DIR="${OUT_DIR:-/tmp/sd_attach_$$}"
  mkdir -p "$ATTACH_DIR"
fi

export SD_ISSUE_JSON="$issue_json" SD_COMMENTS_JSON="$comments_json" SD_ISSUE_KEY="$KEY"
export SD_ATTACH_DIR="$ATTACH_DIR" SD_DOWNLOAD="$DOWNLOAD_ATTACH"

python3 <<'PY'
import json, os, re, subprocess, sys

key = os.environ["SD_ISSUE_KEY"]
issue = json.loads(os.environ["SD_ISSUE_JSON"])
comments = json.loads(os.environ["SD_COMMENTS_JSON"])
base = os.environ.get("SD_BASE", "").rstrip("/")
fields = issue.get("fields") or {}
rendered = issue.get("renderedFields") or {}

def plain(html):
    if not html:
        return ""
    t = re.sub(r"<br\s*/?>", "\n", html, flags=re.I)
    t = re.sub(r"<[^>]+>", "", t)
    t = re.sub(r"\n{3,}", "\n\n", t)
    return t.strip()

desc = plain(rendered.get("description") or fields.get("description") or "")

attachments = fields.get("attachment") or []
att_out = []
for a in attachments:
    att_out.append({
        "id": a.get("id"),
        "filename": a.get("filename"),
        "size": a.get("size"),
        "mimeType": a.get("mimeType"),
        "content_url": a.get("content"),
        "author": (a.get("author") or {}).get("displayName"),
        "created": a.get("created"),
    })

comm_out = []
for c in comments.get("comments") or []:
    comm_out.append({
        "id": c.get("id"),
        "author": (c.get("author") or {}).get("displayName"),
        "created": c.get("created"),
        "body": plain(c.get("body") or ""),
    })

st = fields.get("status") or {}
it = fields.get("issuetype") or {}
asn = fields.get("assignee") or {}
rep = fields.get("reporter") or {}
parent = fields.get("parent") or {}
org = fields.get("customfield_12604")
if isinstance(org, list):
    org_preview = [(x.get("value") if isinstance(x, dict) else x) for x in org]
elif isinstance(org, dict):
    org_preview = org.get("value") or org
else:
    org_preview = org
epic = fields.get("customfield_13109")
subtasks = []
for s in fields.get("subtasks") or []:
    subtasks.append({
        "key": s.get("key"),
        "summary": (s.get("fields") or {}).get("summary"),
        "status": ((s.get("fields") or {}).get("status") or {}).get("name"),
        "issuetype": ((s.get("fields") or {}).get("issuetype") or {}).get("name"),
    })

payload = {
    "key": key,
    "url": f"{base}/browse/{key}" if base else None,
    "summary": fields.get("summary"),
    "status": st.get("name"),
    "issuetype": it.get("name"),
    "assignee": asn.get("displayName") or asn.get("name"),
    "assignee_name": asn.get("name"),
    "reporter": rep.get("displayName") or rep.get("name"),
    "reporter_name": rep.get("name"),
    "organisation": org_preview,
    "epic": epic,
    "parent": parent.get("key"),
    "subtasks": subtasks,
    "priority": (fields.get("priority") or {}).get("name"),
    "created": fields.get("created"),
    "updated": fields.get("updated"),
    "description_text": desc,
    "attachments": att_out,
    "comments": comm_out,
}

print("=== SD_ISSUE ===")
print(json.dumps(payload, ensure_ascii=False, indent=2))
print()
print("=== SD_ISSUE_SUMMARY ===")
print(f"**{key}** [{st.get('name')}] {fields.get('summary')}")
print(f"Assignee: {asn.get('displayName') or '-'} | Reporter: {rep.get('displayName') or '-'} | Updated: {(fields.get('updated') or '')[:16]}")
if org_preview:
    print(f"Organisation: {org_preview}")
if epic:
    print(f"Epic: {epic}")
if parent.get("key"):
    print(f"Parent: {parent.get('key')}")
if subtasks:
    print(f"Subtasks ({len(subtasks)}): " + ", ".join(s["key"] for s in subtasks if s.get("key")))
print()
if desc:
    print("--- Description ---")
    print(desc[:8000])
    if len(desc) > 8000:
        print("... [truncated in summary; see JSON description_text]")
print()
if comm_out:
    print("--- Comments (latest first in JSON order) ---")
    for c in comm_out[-10:]:
        print(f"[{c['created'][:16]}] {c['author']}: {c['body'][:500]}")
print()
if att_out:
    print("--- Attachments ---")
    for a in att_out:
        print(f"- {a['filename']} ({a['size']} bytes) id={a['id']}")
PY

if [[ "$DOWNLOAD_ATTACH" == true ]]; then
  ATTACH_DIR="${OUT_DIR:-/tmp/sd_attach_$$}"
  mkdir -p "$ATTACH_DIR"
  echo "=== SD_ATTACHMENT_DOWNLOAD dir=$ATTACH_DIR ==="
  python3 -c "import json,sys; d=json.load(sys.stdin); \
[print(str(a.get('content',''))+'\t'+str(a.get('filename',''))) for a in d.get('fields',{}).get('attachment',[])]" <<<"$issue_json" |
    while IFS=$'\t' read -r url fname; do
      [[ -z "$url" || -z "$fname" ]] && continue
      safe="$(basename "$fname")"
      dest="${ATTACH_DIR}/${safe}"
      if [[ -n "$SD_REST" && -n "$SD_EMAIL" ]]; then
        if curl -sS -f -L -u "${SD_EMAIL}:${SD_REST}" -o "$dest" "$url"; then
          echo "saved: $safe"
        else
          echo "fail: $safe" >&2
        fi
      elif [[ -n "$SD_BEARER" ]]; then
        if curl -sS -f -L -H "Authorization: Bearer ${SD_BEARER}" -o "$dest" "$url"; then
          echo "saved: $safe"
        else
          echo "fail: $safe" >&2
        fi
      fi
    done
fi
