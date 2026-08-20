#!/usr/bin/env bash
# Agent-safe запуск ansible-playbook для любого ansible-репо (PROD/PREPROD и др.).
# По умолчанию: native ansible в WSL (2.16.x), rsync в /tmp/ext4.
# Fallback: --docker (${ANSIBLE_IMAGE:-example/ansible-runner:1.1}).
#
# Usage:
#   ansible_agent_run.sh --env prod|preprod --limit HOST --playbook playbooks/prepare_servers.yml [options]
#   ansible_agent_run.sh --ansible-root /path/to/ansible --inventory inventories/prod/hosts.ini ...
#
# Options:
#   --ansible-root PATH    корень ansible-репо (вместо --env)
#   --inventory PATH       inventory относительно ansible-root (default по --env)
#   --native               native ansible-playbook (default)
#   --docker               ansible в Docker (legacy)
#   --all                  все хосты инвентаря
#   --ssh-key PATH         приватный ключ (WSL path)
#   --ssh-agent            проброс SSH_AUTH_SOCK (native/docker)
#   --load-global-env      domain_admin_password из ~/.config/ops/.env-lab
#   --mount-artifacts ro   docker: монтировать artifacts (default ro)
#   --no-artifacts         docker: не монтировать artifacts
#   --out PATH             tee лога (WSL path)
#   --timeout-sec N        таймаут (default 7200)
#   --                     аргументы ansible-playbook (-e, --tags, ...)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../lib/infra_paths.sh" ]]; then
  # shellcheck source=../lib/infra_paths.sh
  source "$SCRIPT_DIR/../lib/infra_paths.sh"
  load_infra_paths
fi
: "${GIT_ENV_ROOT:=${HOME}/git}"

ENV=""
ANSIBLE_ROOT=""
INVENTORY=""
LIMIT=""
LIMIT_ALL=""
PLAYBOOK=""
RUN_MODE="native"
SSH_KEY=""
USE_SSH_AGENT=""
LOAD_GLOBAL_ENV=""
MOUNT_ARTIFACTS="ro"
OUT=""
TIMEOUT_SEC=7200
EXTRA_PLAYBOOK=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    --ansible-root) ANSIBLE_ROOT="$2"; shift 2 ;;
    --inventory) INVENTORY="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --all) LIMIT_ALL=1; shift ;;
    --playbook) PLAYBOOK="$2"; shift 2 ;;
    --native) RUN_MODE="native"; shift ;;
    --docker) RUN_MODE="docker"; shift ;;
    --ssh-key) SSH_KEY="$2"; shift 2 ;;
    --ssh-agent) USE_SSH_AGENT=1; shift ;;
    --load-global-env) LOAD_GLOBAL_ENV=1; shift ;;
    --mount-artifacts) MOUNT_ARTIFACTS="$2"; shift 2 ;;
    --no-artifacts) MOUNT_ARTIFACTS=""; shift ;;
    --out) OUT="$2"; shift 2 ;;
    --timeout-sec) TIMEOUT_SEC="$2"; shift 2 ;;
    --) shift; EXTRA_PLAYBOOK=("$@"); break ;;
    -h|--help)
      sed -n '2,25p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -n "$ANSIBLE_ROOT" ]]; then
  ANSIBLE_ROOT="${ANSIBLE_ROOT/#\~/$HOME}"
  [[ "$ANSIBLE_ROOT" != /* ]] && ANSIBLE_ROOT="$(cd "$(dirname "$ANSIBLE_ROOT")" && pwd)/$(basename "$ANSIBLE_ROOT")"
  if [[ -z "$INVENTORY" ]]; then
    echo "ERROR: --inventory required with --ansible-root" >&2
    exit 1
  fi
elif [[ -n "$ENV" ]]; then
  case "$ENV" in
    prod|PROD) ANSIBLE_ROOT="$GIT_ENV_ROOT/PROD/ansible"; INVENTORY="${INVENTORY:-inventories/prod/hosts.ini}" ;;
    preprod|PREPROD) ANSIBLE_ROOT="$GIT_ENV_ROOT/PREPROD/ansible"; INVENTORY="${INVENTORY:-inventories/preprod/hosts.ini}" ;;
    *)
      echo "ERROR: --env prod|preprod or --ansible-root required" >&2
      exit 1
      ;;
  esac
else
  echo "ERROR: --env prod|preprod or --ansible-root required" >&2
  exit 1
fi

case "$ENV" in
  prod|PROD|preprod|PREPROD|"") ;;
  *)
    echo "ERROR: invalid --env: $ENV" >&2
    exit 1
    ;;
esac

if [[ -z "$INVENTORY" ]]; then
  echo "ERROR: inventory not set" >&2
  exit 1
fi

if [[ -z "$PLAYBOOK" ]]; then
  echo "ERROR: --playbook required" >&2
  exit 1
fi
if [[ -z "$LIMIT" && -z "$LIMIT_ALL" ]]; then
  echo "ERROR: --limit HOST or --all required" >&2
  exit 1
fi
if [[ ! -d "$ANSIBLE_ROOT" ]]; then
  echo "ERROR: ansible root not found: $ANSIBLE_ROOT" >&2
  exit 1
fi

if [[ -n "$OUT" ]]; then
  mkdir -p "$(dirname "$OUT")"
  exec > >(tee "$OUT") 2>&1
fi

echo "=== ansible_agent_run $(date -Is) env=$ENV mode=$RUN_MODE playbook=$PLAYBOOK limit=${LIMIT:-ALL} ==="

ANSIBLE_TMP="/tmp/ansible-agent-$$"
cp -a "$ANSIBLE_ROOT/." "$ANSIBLE_TMP/"
chmod -R go-w "$ANSIBLE_TMP"
mkdir -p "$ANSIBLE_TMP/artifacts/root_credentials"
trap 'rm -rf "$ANSIBLE_TMP"' EXIT

EXTRA_JSON="$ANSIBLE_TMP/extra_agent.json"
python_keys=()

if [[ -n "$LOAD_GLOBAL_ENV" ]]; then
  if [[ -f "${HOME}/.config/ops/.env-lab" ]]; then
    # shellcheck disable=SC1091
    source "${HOME}/.config/ops/.env-lab"
  fi
  if [[ -z "${DOMAIN_ADMIN_PASSWORD:-}" ]]; then
    echo "ERROR: --load-global-env requires DOMAIN_ADMIN_PASSWORD in ~/.config/ops/.env-lab" >&2
    exit 1
  fi
  python_keys+=("domain_admin_password")
fi

if [[ -n "$SSH_KEY" ]]; then
  SK="${SSH_KEY/#\~/$HOME}"
  [[ "$SK" != /* ]] && SK="$(cd "$(dirname "$SK")" && pwd)/$(basename "$SK")"
  export SK
  python_keys+=("ansible_ssh_private_key_file" "ansible_private_key_file")
fi

export ANSIBLE_TMP EXTRA_JSON DOMAIN_ADMIN_PASSWORD
_PY_KEYS=$(IFS=,; echo "${python_keys[*]:-}")
export _PY_KEYS
python3 - <<'PY'
import json, os
keys = [k for k in os.environ.get("_PY_KEYS", "").split(",") if k]
extra = {"ansible_ssh_common_args": "-o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"}
for key in keys:
    if key == "domain_admin_password":
        extra[key] = os.environ["DOMAIN_ADMIN_PASSWORD"]
    elif key in ("ansible_ssh_private_key_file", "ansible_private_key_file"):
        extra[key] = os.environ["SK"]
with open(os.environ["EXTRA_JSON"], "w", encoding="utf-8") as f:
    json.dump(extra, f)
PY
chmod 600 "$EXTRA_JSON"
EXTRA_PLAYBOOK=(-e "@$EXTRA_JSON" "${EXTRA_PLAYBOOK[@]}")

if [[ -n "$LIMIT" && "$LIMIT" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  ssh-keyscan -H "$LIMIT" >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
elif [[ -n "$LIMIT" ]]; then
  AH=$(grep -E "^${LIMIT}[[:space:]]" "$ANSIBLE_ROOT/$INVENTORY" 2>/dev/null | grep -oE 'ansible_host=[0-9.]+' | head -1 | cut -d= -f2 || true)
  if [[ -n "$AH" ]]; then
    ssh-keyscan -H "$AH" >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
  fi
fi

LIMIT_OPT=()
[[ -n "$LIMIT" ]] && LIMIT_OPT=(--limit "$LIMIT")

APB=(ansible-playbook -i "$INVENTORY" "$PLAYBOOK" "${LIMIT_OPT[@]}" -f 1 "${EXTRA_PLAYBOOK[@]}")

if [[ "$RUN_MODE" == "native" ]]; then
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "ERROR: ansible-playbook not found in WSL; install ansible-core 2.16 or use --docker" >&2
    exit 127
  fi
  echo "=== native ansible-playbook $(ansible-playbook --version | head -1) timeout ${TIMEOUT_SEC}s ==="
  cd "$ANSIBLE_TMP"
  export ANSIBLE_CONFIG="$ANSIBLE_TMP/ansible.cfg"
  export ANSIBLE_FORKS=1
  if [[ -n "$USE_SSH_AGENT" && -z "${SSH_AUTH_SOCK:-}" ]]; then
    echo "ERROR: --ssh-agent requires SSH_AUTH_SOCK" >&2
    exit 1
  fi
  timeout "$TIMEOUT_SEC" "${APB[@]}"
else
  DOCKER_MOUNTS=(-v "$ANSIBLE_TMP:/work")
  if [[ -n "$SSH_KEY" ]]; then
    DOCKER_MOUNTS+=(-v "$SK:/work/.ssh_key_mount:ro")
  fi
  if [[ -n "$USE_SSH_AGENT" ]]; then
    if [[ -z "${SSH_AUTH_SOCK:-}" || ! -S "$SSH_AUTH_SOCK" ]]; then
      echo "ERROR: --ssh-agent requires SSH_AUTH_SOCK" >&2
      exit 1
    fi
    DOCKER_MOUNTS+=(-v "$SSH_AUTH_SOCK:/ssh-agent")
  fi
  if [[ "$MOUNT_ARTIFACTS" == "ro" ]]; then
    DOCKER_MOUNTS+=(-v "$ANSIBLE_ROOT/artifacts:/work/artifacts:ro")
  fi
  DOCKER_APB=(ansible-playbook -i "/work/$INVENTORY" "$PLAYBOOK" "${LIMIT_OPT[@]}")
  if [[ -n "$SSH_KEY" ]]; then
    DOCKER_APB+=(-e ansible_ssh_private_key_file=/work/.ssh_key_mount -e ansible_private_key_file=/work/.ssh_key_mount)
  fi
  if [[ -n "$USE_SSH_AGENT" ]]; then
    DOCKER_APB+=(-e ansible_ssh_private_key_file= -e ansible_private_key_file=)
  fi
  DOCKER_APB+=(-e 'ansible_ssh_common_args=-o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new' "${EXTRA_PLAYBOOK[@]}")
  echo "=== docker ansible-playbook (timeout ${TIMEOUT_SEC}s) ==="
  timeout "$TIMEOUT_SEC" docker run --rm -i \
    "${DOCKER_MOUNTS[@]}" \
    -w /work \
    --network host \
    -e ANSIBLE_CONFIG=/work/ansible.cfg \
    -e ANSIBLE_ROLES_PATH=/work/roles \
    -e ANSIBLE_FORKS=1 \
    ${USE_SSH_AGENT:+-e SSH_AUTH_SOCK=/ssh-agent} \
    ${ANSIBLE_IMAGE:-example/ansible-runner:1.1} \
    "${DOCKER_APB[@]}"
fi

echo "=== ansible_agent_run done ==="
