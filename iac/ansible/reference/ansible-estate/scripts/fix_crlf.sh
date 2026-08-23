#!/usr/bin/env bash
# Strip CRLF (Windows line endings) from all text files in the repo.
# Run from the ansible directory root: ./scripts/fix_crlf.sh
# After a CRLF import, run once so scripts do not fail with "bash\\r: No such file or directory".
# Excluded: .git, .collections (including nested), artifacts.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
TMPF="/tmp/fix_crlf_$$"
while IFS= read -r -d '' f; do
  sed 's/\r$//' "$f" > "$TMPF" && mv "$TMPF" "$f"
done < <(find . -type f \( \
  -name "*.sh" -o \
  -name "*.yml" -o \
  -name "*.yaml" -o \
  -name "*.ini" -o \
  -name "*.cfg" -o \
  -name "*.md" \
  \) ! -path "./.git/*" ! -path "*/.collections/*" ! -path "./artifacts/*" ! -path "*/artifacts/*" -print0)
rm -f "$TMPF"
echo "CRLF removed in repo under $REPO_ROOT"
