#!/usr/bin/env bash
# Probe SSH config aliases (BatchMode pubkey). Output TSV to stdout or OUT file.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/ssh_agent_env.sh
source "$SCRIPT_DIR/../lib/ssh_agent_env.sh"
ssh_agent_env || true
ssh_util_base_opts

OUT="${OUT:-}"
usage() {
  echo "Usage: $0 [--out FILE] alias [alias ...]" >&2
  echo "       $0 [--out FILE] --file ALIAS_LIST.txt" >&2
  exit 1
}

OUT_FILE=""
ALIASES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT_FILE="$2"; shift 2 ;;
    --file)
      [[ -f "$2" ]] || { echo "missing file: $2" >&2; exit 1; }
      mapfile -t ALIASES < <(grep -v '^#' "$2" | grep -v '^[[:space:]]*$' || true)
      shift 2
      ;;
    -h|--help) usage ;;
    *) ALIASES+=("$1"); shift ;;
  esac
done

[[ ${#ALIASES[@]} -gt 0 ]] || usage

emit() {
  if [[ -n "$OUT_FILE" ]]; then
    echo -e "$1" >>"$OUT_FILE"
  else
    echo -e "$1"
  fi
}

if [[ -n "$OUT_FILE" ]]; then
  : >"$OUT_FILE"
  emit "alias\tip\tconfig_user\tstatus\thostname\terror"
fi

ok=0 fail=0
for alias in "${ALIASES[@]}"; do
  alias="${alias//$'\r'/}"
  ip=$(ssh -G "$alias" 2>/dev/null | awk '/^hostname / {print $2; exit}')
  user=$(ssh -G "$alias" 2>/dev/null | awk '/^user / {print $2; exit}')
  ip="${ip//$'\r'/}"; user="${user//$'\r'/}"
  if [[ -z "$ip" ]]; then
    emit "${alias}\t-\t-\tNO_CONFIG\t-\t-"
    fail=$((fail + 1))
    continue
  fi
  if hn=$(ssh "${SSH_UTIL_OPTS[@]}" "$alias" 'hostname -s' </dev/null 2>/dev/null); then
    emit "${alias}\t${ip}\t${user}\tOK\t${hn}\t-"
    ok=$((ok + 1))
  else
    err=$(ssh "${SSH_UTIL_OPTS[@]}" "$alias" 'true' </dev/null 2>&1 | grep -iE 'connect|timeout|refused|denied|closed|reset' | head -1 | tr '\t' ' ')
    emit "${alias}\t${ip}\t${user}\tFAIL\t-\t${err:-ssh_fail}"
    fail=$((fail + 1))
  fi
done

echo "=== ssh_probe_aliases ok=$ok fail=$fail ===" >&2
[[ -n "$OUT_FILE" ]] && echo "output=$OUT_FILE" >&2
