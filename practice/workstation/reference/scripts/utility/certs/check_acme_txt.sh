#!/usr/bin/env bash
# Generic ACME DNS-01 TXT check before Enter in certbot --manual.
# Exit 0 only when every selected authoritative NS and (by default) public
# resolvers return all expected values.
#
# Usage:
#   check_acme_txt.sh --name _acme-challenge.example.ru --value VAL
#   check_acme_txt.sh --name _acme-challenge.example.ru --value V1 --value V2
#   check_acme_txt.sh --name _acme-challenge.example.invalid --ns-set nic --value VAL
#   check_acme_txt.sh --name _acme-challenge.example.invalid --ns-set ad --no-public --value VAL
#   check_acme_txt.sh --name _acme-challenge.x.example.invalid --ns-set auto --value VAL --out /path/out
set -euo pipefail

NAME=""
ZONE=""
NS_SET="auto"
USE_PUBLIC=true
OUT=""
VALUES=()
EXTRA_NS=()

NIC_NS=(
  ns3-l2.nic.ru
  ns4-l2.nic.ru
  ns8-l2.nic.ru
  ns4-cloud.nic.ru
  ns8-cloud.nic.ru
)
AD_NS=(
  dc01mosvkc.ad.example.invalid
  dc02mosvkc.ad.example.invalid
)
PUBLIC_LIST=(
  8.8.8.8
  8.8.4.4
  1.1.1.1
  1.0.0.1
)

usage() {
  cat <<'EOF' >&2
Usage: check_acme_txt.sh --name FQDN --value VAL [--value VAL2] [options]

Options:
  --name FQDN          TXT name (example: _acme-challenge.example.invalid)
  --value VAL          expected TXT (repeat for wildcard+apex on the same name)
  --zone ZONE          zone for --ns-set auto (default: name without _acme-challenge.)
  --ns-set auto|nic|ad|none
                       auto: dig NS of --zone
                       nic: RU-CENTER / nic.ru list
                       ad: dc01/dc02 ad.example.invalid
                       none: only --ns hosts
  --ns HOST            extra authoritative server (repeatable)
  --public             also check Google+Cloudflare (default)
  --no-public          skip public resolvers (not enough for Let's Encrypt)
  --out FILE           tee full output to FILE
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="${2:-}"; shift 2 ;;
    --value) VALUES+=("${2:-}"); shift 2 ;;
    --zone) ZONE="${2:-}"; shift 2 ;;
    --ns-set) NS_SET="${2:-}"; shift 2 ;;
    --ns) EXTRA_NS+=("${2:-}"); shift 2 ;;
    --public) USE_PUBLIC=true; shift ;;
    --no-public) USE_PUBLIC=false; shift ;;
    --out) OUT="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    --) shift; break ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      ;;
    *)
      VALUES+=("$1")
      shift
      ;;
  esac
done

while [[ $# -gt 0 ]]; do
  VALUES+=("$1")
  shift
done

[[ -n "$NAME" && ${#VALUES[@]} -gt 0 ]] || usage

case "$NS_SET" in
  auto|nic|ad|none) ;;
  *)
    echo "Unknown --ns-set: $NS_SET" >&2
    exit 2
    ;;
esac

if [[ -n "$OUT" ]]; then
  mkdir -p "$(dirname "$OUT")"
  exec > >(tee "$OUT") 2>&1
fi

if [[ -z "$ZONE" ]]; then
  ZONE="${NAME#_acme-challenge.}"
fi

NS_LIST=()
case "$NS_SET" in
  nic) NS_LIST=("${NIC_NS[@]}") ;;
  ad) NS_LIST=("${AD_NS[@]}") ;;
  none) NS_LIST=() ;;
  auto)
    mapfile -t NS_LIST < <(dig NS "$ZONE" +short 2>/dev/null | sed 's/\.$//' | sort -u)
    ;;
esac

if [[ ${#EXTRA_NS[@]} -gt 0 ]]; then
  NS_LIST+=("${EXTRA_NS[@]}")
fi

# Unique NS, skip empty
declare -A seen_ns=()
UNIQ_NS=()
for ns in "${NS_LIST[@]}"; do
  [[ -n "$ns" ]] || continue
  ns="${ns%.}"
  [[ -z "${seen_ns[$ns]:-}" ]] || continue
  seen_ns[$ns]=1
  UNIQ_NS+=("$ns")
done
NS_LIST=("${UNIQ_NS[@]}")

has_value() {
  local needle="$1"
  local line
  shift
  for line in "$@"; do
    line=${line//\"/}
    [[ "$line" == "$needle" ]] && return 0
  done
  return 1
}

all_values_present() {
  local v
  for v in "${VALUES[@]}"; do
    has_value "$v" "$@" || return 1
  done
  return 0
}

echo "=== $(date -Is) TXT check $NAME ==="
echo "Zone: $ZONE"
echo "NS set: $NS_SET"
echo "Public resolvers: $USE_PUBLIC"
printf 'Expected (%s): %s\n' "${#VALUES[@]}" "${VALUES[*]}"
echo

if [[ ${#NS_LIST[@]} -eq 0 ]]; then
  echo "ERROR: no authoritative NS. Pass --ns-set nic|ad or --ns HOST, or check --zone."
  exit 2
fi

ok_ns=0
ns_count=${#NS_LIST[@]}
for ns in "${NS_LIST[@]}"; do
  echo "--- @$ns (+norecurse) ---"
  dig TXT "$NAME" @"$ns" +norecurse +time=5 +tries=2 || true
  mapfile -t vals < <(dig TXT "$NAME" @"$ns" +short +norecurse 2>/dev/null | tr -d '"')
  printf 'parsed: [%s]\n' "${vals[*]:-}"
  if all_values_present "${vals[@]:-}"; then
    echo "RESULT: MATCH"
    ok_ns=$((ok_ns + 1))
  else
    echo "RESULT: NO MATCH"
  fi
  echo
done

ok_pub=0
pub_count=0
if [[ "$USE_PUBLIC" == true ]]; then
  pub_count=${#PUBLIC_LIST[@]}
  echo "=== Public resolvers (Google + Cloudflare) ==="
  for resolver in "${PUBLIC_LIST[@]}"; do
    echo "--- @$resolver ---"
    dig TXT "$NAME" @"$resolver" +time=5 +tries=2 || true
    mapfile -t vals < <(dig TXT "$NAME" @"$resolver" +short 2>/dev/null | tr -d '"')
    printf 'parsed: [%s]\n' "${vals[*]:-}"
    if all_values_present "${vals[@]:-}"; then
      echo "RESULT: MATCH"
      ok_pub=$((ok_pub + 1))
    else
      echo "RESULT: NO MATCH"
    fi
    echo
  done
fi

echo "=== Summary ==="
echo "authoritative NS ok: $ok_ns / $ns_count"
if [[ "$USE_PUBLIC" == true ]]; then
  echo "public (Google+CF) ok: $ok_pub / $pub_count"
fi

if [[ "$ok_ns" -eq "$ns_count" && "$USE_PUBLIC" == true && "$ok_pub" -eq "$pub_count" ]]; then
  echo "OK: authoritative and public resolvers see TXT, safe to press Enter in certbot"
  exit 0
fi
if [[ "$ok_ns" -eq "$ns_count" && "$USE_PUBLIC" == false ]]; then
  echo "OK_NS_ONLY: authoritative NS match. Public check skipped; Let's Encrypt follows public DNS."
  exit 0
fi
if [[ "$ok_ns" -eq "$ns_count" && "$USE_PUBLIC" == true && "$ok_pub" -lt "$pub_count" ]]; then
  echo "WAIT: authoritative NS already have TXT, public resolvers still catching up"
  exit 1
fi
echo "WAIT: TXT not on all authoritative NS yet"
exit 1
