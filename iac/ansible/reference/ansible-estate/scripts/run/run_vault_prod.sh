#!/usr/bin/env bash
# Delegate to the living Vault runner (same tree as playbooks/vault-*.yml).
set -euo pipefail
exec "$(cd "$(dirname "$0")" && pwd)/../prod/run-vault.sh" "$@"
