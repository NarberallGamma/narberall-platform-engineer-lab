#!/usr/bin/env bash
# Синхронизация воркфлоу n8n из репо (GitOps). Плейбук на localhost — SSH не используется.
# Для удалённых хостов см. scripts/run/lib/docker_ssh.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
# Подхват Vault-переменных с контрол-ноды (создаются пайплайном из CI Variables в /ansible/.env.vault).
[ -f .env.vault ] && source .env.vault

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-git.example.com/platform-infra/base-images/ansible:1.0}"

# Синхронизация воркфлоу n8n из репо (GitOps). Плейбук выполняется на localhost, вызов API n8n по сети.
# --all / -A: синхронизировать все воркфлоу из group_vars (n8n_workflows_to_sync).
# --workflow <имя>: синхронизировать только указанный воркфлоу (имя файла без .json в roles/n8n_workflows/files/workflows/).
# Без аргументов — то же, что --all.
# Пример (все):     ./run_n8n_workflows.sh
# Пример (все):     ./run_n8n_workflows.sh --all
# Пример (один):    ./run_n8n_workflows.sh --workflow nextcloud_groupfolders_webhook
INV="inventories/localhost/hosts.ini"
EXTRA=()
SYNC_ALL=""
WORKFLOW_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all|-A)           SYNC_ALL=1; shift ;;
    --workflow|-w)      WORKFLOW_NAME="$2"; shift 2 ;;
    -e)                 EXTRA+=("$1"); shift; [[ $# -gt 0 ]] && EXTRA+=("$1"); shift ;;
    --help|-h)          echo "Использование: $0 [--all | --workflow ИМЯ] [-e KEY=VAL ...]"; echo "  --all, -A       синхронизировать все воркфлоу из group_vars"; echo "  --workflow, -w  синхронизировать только воркфлоу ИМЯ (файл workflows/ИМЯ.json)"; echo "  без аргументов  то же, что --all"; exit 0 ;;
    *)
      EXTRA+=("$1"); shift
      ;;
  esac
done

# Один воркфлоу: передать список из одного элемента (имя как в файле workflows/ИМЯ.json).
# Все воркфлоу: не передавать n8n_workflows_to_sync — берётся из group_vars.
if [[ -n "$WORKFLOW_NAME" ]]; then
  EXTRA=(-e "n8n_workflows_to_sync=[\"$WORKFLOW_NAME\"]" "${EXTRA[@]}")
fi
# Если явно передан --all, список не переопределяем (из group_vars).

# Vault: передать VAULT_ADDR и VAULT_TOKEN из окружения в контейнер (для роли n8n_init).
VAULT_ENV=()
[[ -n "${VAULT_ADDR:-}" ]] && VAULT_ENV+=(-e "VAULT_ADDR=$VAULT_ADDR")
[[ -n "${VAULT_TOKEN:-}" ]] && VAULT_ENV+=(-e "VAULT_TOKEN=$VAULT_TOKEN")

# Лог вывода плейбука в artifacts/logs для отладки
LOG_DIR="artifacts/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/n8n_workflows_$(date +%Y-%m-%d_%H-%M-%S).log"
echo "Лог вывода: $LOG_FILE" >&2

# При ручном запуске в терминале — -it для удобного вывода; из cron/CI TTY нет — без -it
DOCKER_TTY=""
[[ -t 0 ]] && [[ -t 1 ]] && DOCKER_TTY="-it"
docker run --rm $DOCKER_TTY \
  -v "$(pwd):/work" -w /work \
  "${VAULT_ENV[@]}" \
  --network host \
  -e ANSIBLE_CONFIG=/work/ansible.cfg \
  -e ANSIBLE_ROLES_PATH=/work/roles \
  "$ANSIBLE_IMAGE" \
  ansible-playbook -i "/work/$INV" playbooks/n8n_workflows.yml "${EXTRA[@]}" 2>&1 | tee "$LOG_FILE"
