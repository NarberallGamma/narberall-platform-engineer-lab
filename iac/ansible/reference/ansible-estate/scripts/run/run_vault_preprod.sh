#!/usr/bin/env bash
# Delegate to the living Vault runner (same tree as playbooks/vault-*.yml).
set -euo pipefail
exec "$(cd "$(dirname "$0")" && pwd)/../preprod/run-vault.sh" "$@"
