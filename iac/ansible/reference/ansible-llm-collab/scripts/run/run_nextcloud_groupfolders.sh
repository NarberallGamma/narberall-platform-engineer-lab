#!/usr/bin/env bash
# Nextcloud groupfolders. SSH-ключ с passphrase: eval "$(ssh-agent -s)" && ssh-add ~/.ssh/your_key
#   ./scripts/run/run_nextcloud_groupfolders.sh --profile nextcloud-dev --limit HOST --ssh-key ~/.ssh/your_key --ssh-agent
# Подробнее: scripts/run/lib/docker_ssh.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=lib/docker_ssh.sh
source "$(dirname "$0")/lib/docker_ssh.sh"
# Подхват Vault-переменных с контрол-ноды (создаются пайплайном из CI Variables в /ansible/.env.vault).
[ -f .env.vault ] && source .env.vault

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-git.example.com/platform-infra/base-images/ansible:1.0}"

# Обязательно одно из: --limit <хост из инвентаря> ИЛИ --profile nextcloud-dev|nextcloud-prod|regul (тогда выбирается хост по умолчанию: см. блок резолва ниже, должен совпадать с group_vars nextcloud_profile_default_inventory_host).
# Профиль: --profile задаёт матрицу/WebDAV/Vault (nextcloud_matrix_profile_by_host подставляется для этого запуска). Можно сочетать с --limit.
# Режим «один клиент»: передать имя клиента аргументом (с пробелами — в кавычках).
# Режим «все клиенты»: --all-clients — список папок из WebDAV, применение прав по матрице ко всем (client_name не нужен).
# Режим «все клиенты + создание папок по матрице»: --all-clients-create — то же + идемпотентный MKCOL для каждого клиента, затем ACL.
# Режим «только ACL одному»: --permissions-only и имя клиента — переиграть ACL по матрице без MKCOL WebDAV (тест одной папки).
# Режим «сброс LDAP»: --ldap-reset — только occ ldap:reset-group для групп из nextcloud_ldap_reset_groups (client_name не нужен).
# Пример (один клиент, dev): ./run_nextcloud_groupfolders.sh --profile nextcloud-dev "ООО Рога и Копыта"
# Пример (Regul, хост берётся из профиля app-02.example.com): ./run_nextcloud_groupfolders.sh --profile regul "Имя клиента"
# Пример (--limit без смены профиля из group_vars): ./run_nextcloud_groupfolders.sh --limit nextcloud-dev.example.com "ООО …"
# Пример (все клиенты):  ./run_nextcloud_groupfolders.sh --profile nextcloud-dev --all-clients
# Пример (все клиенты, MKCOL+ACL): ./run_nextcloud_groupfolders.sh --profile regul --all-clients-create
# Пример (только ACL одному, без MKCOL): ./run_nextcloud_groupfolders.sh --profile regul --permissions-only "Имя клиента"
# Пример (LDAP reset):   ./run_nextcloud_groupfolders.sh --profile nextcloud-dev --ldap-reset
# Параллелизм (Ansible throttle): --mkcol-threads N, --occ-threads N (переопределяют group_vars; без флагов — значения из group_vars/defaults).
# Пример: ./run_nextcloud_groupfolders.sh --profile nextcloud-dev --mkcol-threads 4 --occ-threads 4 "ООО …"
INV="inventories/hosts.ini"
LIMIT_HOST=""
MATRIX_PROFILE=""
SSH_KEY_PATH=""
ASK_PASS=""
USE_SSH_AGENT=""
EXTRA=()
CLIENT_NAME_ARG=""
REAPPLY_ALL_CLIENTS=""
ALL_CLIENTS_MKCOL=""
LDAP_RESET=""
PERMISSIONS_ONLY=""
NC_CONCURRENCY_MKCOL=""
NC_CONCURRENCY_OCC=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit|-L)        LIMIT_HOST="$2"; shift 2 ;;
    --profile|-p)      MATRIX_PROFILE="$2"; shift 2 ;;
    --all-clients|-A)  REAPPLY_ALL_CLIENTS=1; shift ;;
    --all-clients-create|--all-clients-mkcol) ALL_CLIENTS_MKCOL=1; REAPPLY_ALL_CLIENTS=1; shift ;;
    --permissions-only|--acl-only) PERMISSIONS_ONLY=1; shift ;;
    --ldap-reset)      LDAP_RESET=1; shift ;;
    --mkcol-threads|--mkcol-concurrency) NC_CONCURRENCY_MKCOL="$2"; shift 2 ;;
    --occ-threads|--occ-concurrency)     NC_CONCURRENCY_OCC="$2"; shift 2 ;;
    --local|-l)        INV="inventories/localhost/hosts.ini"; shift ;;
    --remote|-r)      INV="inventories/hosts.ini"; shift ;;
    --ssh-key|-k)     SSH_KEY_PATH="$2"; shift 2 ;;
    --ssh-agent)      USE_SSH_AGENT=1; shift ;;
    --ask-pass)       ASK_PASS=1; shift ;;
    -e)               EXTRA+=("$1"); shift; [[ $# -gt 0 ]] && EXTRA+=("$1"); shift ;;
    *)
      if [[ -z "$CLIENT_NAME_ARG" ]] && [[ -z "$REAPPLY_ALL_CLIENTS" ]] && [[ -z "$LDAP_RESET" ]] && [[ "$1" != -* ]]; then
        CLIENT_NAME_ARG="$1"
        shift
      else
        EXTRA+=("$1"); shift
      fi
      ;;
  esac
done

if [[ -n "$PERMISSIONS_ONLY" ]] && [[ -n "$REAPPLY_ALL_CLIENTS" ]]; then
  echo "Ошибка: нельзя одновременно указывать --permissions-only и --all-clients / --all-clients-create." >&2
  exit 1
fi
if [[ -n "$PERMISSIONS_ONLY" ]] && [[ -n "$ALL_CLIENTS_MKCOL" ]]; then
  echo "Ошибка: нельзя одновременно указывать --permissions-only и --all-clients-create." >&2
  exit 1
fi
if [[ -n "$PERMISSIONS_ONLY" ]] && [[ -n "$LDAP_RESET" ]]; then
  echo "Ошибка: нельзя одновременно указывать --permissions-only и --ldap-reset." >&2
  exit 1
fi
# Если имя клиента передано одним аргументом — пишем в файл и передаём -e @файл (через аргументы Docker пробелы режутся)
CLIENT_VARS_FILE=""
MATRIX_VARS_FILE=""
if [[ -n "$CLIENT_NAME_ARG" ]]; then
  CLIENT_VARS_FILE=".ansible_client_vars.json"
  escaped="${CLIENT_NAME_ARG//\\/\\\\}"
  escaped="${escaped//\"/\\\"}"
  printf '{"client_name": "%s"}\n' "$escaped" > "$CLIENT_VARS_FILE"
  EXTRA=(-e "@${CLIENT_VARS_FILE}" "${EXTRA[@]}")
fi
# Режим «все клиенты»: nextcloud_reapply_all_clients_enabled; при --all-clients-create — ещё nextcloud_reapply_all_clients_mkcol_enabled
if [[ -n "$REAPPLY_ALL_CLIENTS" ]]; then
  EXTRA=(-e "nextcloud_reapply_all_clients_enabled=true" "${EXTRA[@]}")
fi
if [[ -n "$ALL_CLIENTS_MKCOL" ]]; then
  EXTRA=(-e "nextcloud_reapply_all_clients_mkcol_enabled=true" "${EXTRA[@]}")
fi
# Режим «только ACL одному»: nextcloud_reapply_permissions_only без MKCOL
if [[ -n "$PERMISSIONS_ONLY" ]]; then
  EXTRA=(-e "nextcloud_reapply_permissions_only=true" "${EXTRA[@]}")
fi
# Режим «сброс LDAP»: только occ ldap:reset-group для групп из group_vars (client_name не передаём)
if [[ -n "$LDAP_RESET" ]]; then
  EXTRA=(-e "nextcloud_ldap_reset_groups_enabled=true" "${EXTRA[@]}")
fi

# Если --profile без --limit: выбрать хост инвентаря (должен совпадать с inventories/hosts.ini и group_vars/nextcloud_profile_default_inventory_host)
if [[ -z "$LIMIT_HOST" ]] && [[ -n "$MATRIX_PROFILE" ]]; then
  case "$MATRIX_PROFILE" in
    nextcloud-dev)
      LIMIT_HOST="nextcloud-dev.example.com"
      ;;
    nextcloud-prod)
      LIMIT_HOST="nextcloud-prod-oc3.example.com"
      ;;
    regul)
      LIMIT_HOST="app-02.example.com"
      ;;
    *)
      echo "Ошибка: неизвестный --profile для авто-хоста: ${MATRIX_PROFILE} (ожидаются nextcloud-dev, nextcloud-prod или regul). Используйте --limit явно или расширьте блок резолва в скрипте." >&2
      exit 1
      ;;
  esac
fi

if [[ -z "$LIMIT_HOST" ]]; then
  echo "Ошибка: задайте --limit <хост из инвентаря> или --profile nextcloud-dev|nextcloud-prod|regul Пример: --profile nextcloud-dev \"ООО …\"" >&2
  exit 1
fi

if [[ -n "$NC_CONCURRENCY_MKCOL" ]] && ! [[ "$NC_CONCURRENCY_MKCOL" =~ ^[1-9][0-9]*$ ]]; then
  echo "Ошибка: --mkcol-threads ожидает целое число >= 1 (получено: ${NC_CONCURRENCY_MKCOL})" >&2
  exit 1
fi
if [[ -n "$NC_CONCURRENCY_OCC" ]] && ! [[ "$NC_CONCURRENCY_OCC" =~ ^[1-9][0-9]*$ ]]; then
  echo "Ошибка: --occ-threads ожидает целое число >= 1 (получено: ${NC_CONCURRENCY_OCC})" >&2
  exit 1
fi

# Явный профиль матрицы для выбранного --limit: через JSON-файл, чтобы переменная пришла в Ansible как dict, а не str
# (inline -e nextcloud_matrix_profile_by_host={...} после docker/ansible часто даёт строку → ошибка доступа [...] по inventory_hostname).
if [[ -n "$MATRIX_PROFILE" ]]; then
  case "$MATRIX_PROFILE" in
    nextcloud-dev|nextcloud-prod|regul)
      MATRIX_VARS_FILE=".ansible_matrix_profile_by_host.json"
      printf '{"nextcloud_matrix_profile_by_host":{"%s":"%s"}}\n' "$LIMIT_HOST" "$MATRIX_PROFILE" > "$MATRIX_VARS_FILE"
      EXTRA=(-e "@${MATRIX_VARS_FILE}" "${EXTRA[@]}")
      ;;
    *)
      echo "Ошибка: --profile: допустимы nextcloud-dev, nextcloud-prod или regul (получено: ${MATRIX_PROFILE})" >&2
      exit 1
      ;;
  esac
fi

_NC_GF_CLEANUP=()
[[ -n "${CLIENT_VARS_FILE:-}" ]] && [[ -f "$CLIENT_VARS_FILE" ]] && _NC_GF_CLEANUP+=("$CLIENT_VARS_FILE")
[[ -n "${MATRIX_VARS_FILE:-}" ]] && [[ -f "$MATRIX_VARS_FILE" ]] && _NC_GF_CLEANUP+=("$MATRIX_VARS_FILE")
if ((${#_NC_GF_CLEANUP[@]} > 0)); then
  trap 'rm -f "${_NC_GF_CLEANUP[@]}"' EXIT
fi

# Параллелизм MKCOL/OCC: в конец EXTRA — перекрывает group_vars при явной передаче
[[ -n "$NC_CONCURRENCY_MKCOL" ]] && EXTRA+=(-e "nextcloud_concurrency_mkcol=${NC_CONCURRENCY_MKCOL}")
[[ -n "$NC_CONCURRENCY_OCC" ]] && EXTRA+=(-e "nextcloud_concurrency_occ=${NC_CONCURRENCY_OCC}")

if [[ -n "$PERMISSIONS_ONLY" ]] && [[ -z "$CLIENT_NAME_ARG" ]]; then
  echo "Ошибка: --permissions-only требует имя клиента, например: $0 --profile regul --permissions-only \"Имя клиента\"" >&2
  exit 1
fi

if [[ -z "$CLIENT_NAME_ARG" ]] && [[ -z "$REAPPLY_ALL_CLIENTS" ]] && [[ -z "$LDAP_RESET" ]] && [[ -z "$PERMISSIONS_ONLY" ]]; then
  echo "Ошибка: укажите имя клиента, --all-clients, --all-clients-create или --ldap-reset. Пример: $0 --profile nextcloud-dev \"ООО Рога и Копыта\" | $0 --profile regul \"…\" | $0 --limit nextcloud-dev.example.com …" >&2
  exit 1
fi

DOCKER_MOUNTS=()
DOCKER_ENV=(-e ANSIBLE_CONFIG=/work/ansible.cfg -e ANSIBLE_ROLES_PATH=/work/roles)
ANSIBLE_EXTRA=()
docker_ssh_apply
if [[ -z "$SSH_KEY_PATH" && -z "$USE_SSH_AGENT" && -z "$ASK_PASS" && -f .ssh/ansible_ssh_key ]]; then
  DOCKER_MOUNTS+=(-v "$(pwd)/.ssh:/work/.ssh:ro")
  ANSIBLE_EXTRA+=(-e ansible_ssh_private_key_file=/work/.ssh/ansible_ssh_key)
fi

VAULT_ENV=()
[[ -n "${VAULT_ADDR:-}" ]] && VAULT_ENV+=(-e "VAULT_ADDR=$VAULT_ADDR")
[[ -n "${VAULT_TOKEN:-}" ]] && VAULT_ENV+=(-e "VAULT_TOKEN=$VAULT_TOKEN")

# Лог вывода плейбука в artifacts/logs (имя плейбука + дата/время) для отладки
LOG_DIR="artifacts/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/nextcloud_groupfolders_$(date +%Y-%m-%d_%H-%M-%S).log"
echo "Лог вывода: $LOG_FILE" >&2

# При ручном запуске в терминале — -it для удобного вывода; из n8n по SSH TTY нет — без -it
DOCKER_TTY=""
[[ -t 0 ]] && [[ -t 1 ]] && DOCKER_TTY="-it"
docker run --rm $DOCKER_TTY \
  -v "$(pwd):/work" -w /work \
  "${DOCKER_MOUNTS[@]}" \
  "${VAULT_ENV[@]}" \
  "${DOCKER_ENV[@]}" \
  --network host \
  "$ANSIBLE_IMAGE" \
  ansible-playbook -i "/work/$INV" playbooks/nextcloud_groupfolders.yml --limit "$LIMIT_HOST" "${ANSIBLE_EXTRA[@]}" "${EXTRA[@]}" 2>&1 | tee "$LOG_FILE"
