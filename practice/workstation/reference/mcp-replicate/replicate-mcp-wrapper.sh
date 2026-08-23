#!/usr/bin/env bash
set -euo pipefail
CREDENTIALS="${HOME}/.config/replicate/credentials.env"
if [[ ! -f "${CREDENTIALS}" ]]; then
  echo "Missing ${CREDENTIALS}" >&2
  exit 1
fi
# shellcheck disable=SC1090
set -a
source "${CREDENTIALS}"
set +a

# Node/undici does not support socks5h. The API usually goes direct.
# When a local v2ray SOCKS listener is up — only a marker for the replicate-img CLI.
if timeout 0.2 bash -c 'echo >/dev/tcp/127.0.0.1/10808' 2>/dev/null; then
  export REPLICATE_SOCKS="${REPLICATE_SOCKS:-socks5h://127.0.0.1:10808}"
fi

exec npx -y replicate-mcp@latest "$@"
