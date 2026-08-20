#!/usr/bin/env bash
# Вызывается модулем ansible.builtin.script. Переменные среды: GF_CONTAINER, GF_FOLDER_ID,
# GF_GROUP, GF_PATH, GF_OP (allow|deny), GF_PERMS, GF_PATH_ALT (альтернативный полный путь или пусто),
# GF_IGNORE_PATH_NOT_FOUND (0|1).
set -u

PATH_NOT_FOUND='Path not found in folder'

run_occ() {
  if [[ "$GF_OP" == "deny" ]]; then
    docker exec -u www-data "$GF_CONTAINER" php occ --no-warnings groupfolders:permissions \
      "$GF_FOLDER_ID" "$1" --group="$GF_GROUP" -- $GF_PERMS
  else
    docker exec -u www-data "$GF_CONTAINER" php occ --no-warnings groupfolders:permissions \
      "$GF_FOLDER_ID" "$1" --group="$GF_GROUP" $GF_PERMS
  fi
}

last_out=""
last_rc=1
found_path_not_found=0

_paths=("$GF_PATH")
_alt="${GF_PATH_ALT:-}"
if [[ -n "$_alt" && "$_alt" != "$GF_PATH" ]]; then
  _paths+=("$_alt")
fi

for try_path in "${_paths[@]}"; do
  [[ -z "$try_path" ]] && continue
  last_out="$(run_occ "$try_path" 2>&1)" && last_rc=0 || last_rc=$?
  if [[ "$last_rc" -eq 0 ]]; then
    printf '%s\n' "$last_out"
    exit 0
  fi
  if printf '%s\n' "$last_out" | grep -Fq "$PATH_NOT_FOUND"; then
    found_path_not_found=1
    last_rc=255
    continue
  fi
  printf '%s\n' "$last_out"
  exit "$last_rc"
done

printf '%s\n' "$last_out"
if [[ "$found_path_not_found" -eq 1 && "${GF_IGNORE_PATH_NOT_FOUND:-0}" == "1" ]]; then
  exit 0
fi
exit "$last_rc"
