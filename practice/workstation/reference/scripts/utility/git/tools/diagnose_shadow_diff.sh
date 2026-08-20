#!/usr/bin/env bash
# Detect CRLF/EOL-only phantom git diffs (shadow changes on Windows checkout)
set -u

REPO="${1:-}"
if [[ -z "$REPO" || ! -d "$REPO/.git" ]]; then
  echo "Usage: $0 /path/to/repo"
  exit 1
fi

cd "$REPO"
echo "=== $(basename "$REPO") ==="
git status -sb

dirty=$(git status --porcelain | wc -l)
full=$(git diff --stat 2>/dev/null | tail -1)
eol=$(git diff --ignore-space-at-eol --stat 2>/dev/null | tail -1)

echo "dirty_files=$dirty"
echo "full_diff: ${full:-none}"
echo "eol_ignored: ${eol:-empty}"

sample=$(git diff --name-only | head -1)
if [[ -n "$sample" && -f "$sample" ]]; then
  echo "sample: $sample"
  file "$sample" 2>/dev/null || true
  if git show "HEAD:$sample" >/dev/null 2>&1; then
    git show "HEAD:$sample" | file - 2>/dev/null || true
  fi
  if [[ -z "$(git diff --ignore-space-at-eol -- "$sample")" ]]; then
    echo "verdict: EOL-ONLY phantom (CRLF vs LF)"
  else
    echo "verdict: REAL content changes present"
    git diff --ignore-space-at-eol -- "$sample" | head -30
  fi
else
  if [[ "$dirty" -eq 0 ]]; then
    echo "verdict: clean"
  else
    echo "verdict: staged or other — check git status"
  fi
fi
