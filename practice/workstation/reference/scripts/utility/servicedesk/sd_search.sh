#!/usr/bin/env bash
# Search Jira issues (default project INFRA) with optional time window.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sd_lib.sh
source "$SCRIPT_DIR/sd_lib.sh"

PROJECT="INFRA"
PERIOD=""
JQL_EXTRA=""
JQL_FULL=""
MAX=100
FORMAT="agent"
FIELDS="summary,status,issuetype,assignee,updated,created,reporter,priority"

usage() {
  cat <<EOF
Usage: sd_search.sh [options]

Options:
  --project KEY       Project key (default: INFRA; ignored if --jql-full)
  --period PERIOD     today | 1d | 7d | week | 30d | month | 90d | all
  --jql FRAGMENT      Extra JQL AND fragment (quoted)
  --jql-full QUERY    Use QUERY as complete JQL (no auto project/period)
  --max N             Max issues to fetch (default 100, paginated)
  --format agent|json agent = summary + markdown table + JSON issues array
  -h                  Help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --period) PERIOD="$2"; shift 2 ;;
    --jql) JQL_EXTRA="$2"; shift 2 ;;
    --jql-full) JQL_FULL="$2"; shift 2 ;;
    --max) MAX="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

sd_load_env
export SD_BASE

if [[ -n "$JQL_FULL" ]]; then
  JQL="$JQL_FULL"
  if [[ "$JQL" != *ORDER\ BY* ]]; then
    JQL+=" ORDER BY updated DESC"
  fi
else
  parts=("project = ${PROJECT}")
  frag="$(sd_period_to_jql_fragment "$PERIOD" 2>/dev/null || true)"
  [[ -n "$frag" ]] && parts+=("$frag")
  [[ -n "$JQL_EXTRA" ]] && parts+=("($JQL_EXTRA)")
  JQL="${parts[0]}"
  for ((i = 1; i < ${#parts[@]}; i++)); do
    JQL+=" AND ${parts[$i]}"
  done
  JQL+=" ORDER BY updated DESC"
fi

enc_jql="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$JQL")"

all_issues="[]"
start=0
page=50
fetched=0
total=0

while [[ "$fetched" -lt "$MAX" ]]; do
  limit="$page"
  if (( fetched + limit > MAX )); then
    limit=$((MAX - fetched))
  fi
  url="${SD_BASE}/rest/api/2/search?jql=${enc_jql}&startAt=${start}&maxResults=${limit}&fields=${FIELDS}"
  sd_curl_get "$url"
  chunk="$SD_LAST_BODY"
  total="$(python3 -c "import json,sys; print(json.load(sys.stdin)['total'])" <<<"$chunk")"
  all_issues="$(python3 -c "
import json, sys
acc = json.loads(sys.argv[1])
data = json.loads(sys.argv[2])
acc.extend(data.get('issues', []))
print(json.dumps(acc, ensure_ascii=False))
" "$all_issues" "$chunk")"
  got="$(python3 -c "import json,sys; print(len(json.load(sys.stdin).get('issues',[])))" <<<"$chunk")"
  fetched=$((fetched + got))
  start=$((start + got))
  if (( got == 0 || start >= total )); then
    break
  fi
done

if [[ -n "$JQL_FULL" ]]; then
  SD_OUT_PROJECT="*"
else
  SD_OUT_PROJECT="$PROJECT"
fi
export SD_OUT_JQL="$JQL" SD_OUT_PROJECT="$SD_OUT_PROJECT" SD_OUT_PERIOD="$PERIOD" SD_OUT_TOTAL="$total" SD_OUT_FETCHED="$fetched"
export SD_OUT_ISSUES="$all_issues"

python3 <<'PY'
import json, os, textwrap

jql = os.environ["SD_OUT_JQL"]
project = os.environ["SD_OUT_PROJECT"]
period = os.environ["SD_OUT_PERIOD"] or "all"
total = int(os.environ["SD_OUT_TOTAL"])
fetched = int(os.environ["SD_OUT_FETCHED"])
issues_raw = json.loads(os.environ["SD_OUT_ISSUES"])

def slim(i):
    f = i.get("fields") or {}
    st = f.get("status") or {}
    it = f.get("issuetype") or {}
    asn = f.get("assignee") or {}
    rep = f.get("reporter") or {}
    pr = f.get("priority") or {}
    return {
        "key": i.get("key"),
        "summary": f.get("summary"),
        "status": st.get("name"),
        "issuetype": it.get("name"),
        "priority": pr.get("name"),
        "assignee": asn.get("displayName") or asn.get("name"),
        "reporter": rep.get("displayName") or rep.get("name"),
        "updated": f.get("updated"),
        "created": f.get("created"),
    }

# inject base url for browse links
slimmed = [slim(i) for i in issues_raw]
base = os.environ.get("SD_BASE", "").rstrip("/")
for row in slimmed:
    if row.get("key"):
        row["url"] = f"{base}/browse/{row['key']}"

meta = {
    "project": project,
    "period": period,
    "jql": jql,
    "total_matching": total,
    "returned": len(slimmed),
}

print("=== SD_SEARCH ===")
print(json.dumps({"meta": meta, "issues": slimmed}, ensure_ascii=False, indent=2))
print()
print("=== SD_TABLE ===")
print(f"| Key | Type | Status | Updated | Assignee | Summary |")
print(f"|-----|------|--------|---------|----------|---------|")
for row in slimmed:
    summ = (row["summary"] or "").replace("|", "/")
    if len(summ) > 80:
        summ = summ[:77] + "..."
    upd = (row["updated"] or "")[:16].replace("T", " ")
    print(f"| {row['key']} | {row['issuetype']} | {row['status']} | {upd} | {row['assignee'] or '-'} | {summ} |")
PY
