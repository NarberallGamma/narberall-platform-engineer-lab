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
exec npx -y replicate-mcp@latest "$@"
