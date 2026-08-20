#!/usr/bin/env bash
# Удаление CRLF (Windows-окончаний строк) во всех текстовых файлах репо.
# Запускать из корня каталога ansible: ./scripts/fix_crlf.sh
# После импорта с CRLF выполнить один раз, чтобы скрипты не падали с «bash\\r: No such file or directory».
# Исключены: .git, .collections (в т.ч. вложенные), artifacts.
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
