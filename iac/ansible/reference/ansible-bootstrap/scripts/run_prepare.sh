#!/usr/bin/env bash
# Run prepare_servers via ansible-runner. Execute from iac/ansible/reference/ansible-bootstrap/.
set -euo pipefail

ANSIBLE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ANSIBLE_ROOT"

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-example/ansible-runner:1.1}"
INV="inventories/hosts.ini"
SSH_KEY_PATH=""
NO_TTY=0
EXTRA=()

usage() {
  cat <<'EOF'
Usage: run_prepare.sh [options] [-- ansible-playbook args...]

  --limit HOST        pass through to ansible-playbook
  -k, --ssh-key PATH  private key mounted into the runner
  --image TAG         ansible-runner image
  --no-tty            docker run without TTY (CI / non-interactive)
  --tags TAGS

Examples:
  ./scripts/run_prepare.sh --limit vps-1.example.com
  ./scripts/run_prepare.sh --tags ssh_hardening -e enable_ssh_hardening=true --no-tty
EOF
}

LIMIT=""
TAGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit)      LIMIT="$2"; shift 2 ;;
    --ssh-key|-k) SSH_KEY_PATH="$2"; shift 2 ;;
    --image)      ANSIBLE_IMAGE="$2"; shift 2 ;;
    --no-tty)     NO_TTY=1; shift ;;
    --tags)       TAGS=(--tags "$2"); shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    --)           shift; EXTRA+=("$@"); break ;;
    *)            EXTRA+=("$1"); shift ;;
  esac
done

if ! command -v docker &>/dev/null; then
  echo "run_prepare.sh: docker not found." >&2
  exit 1
fi

DOCKER_MOUNTS=(-v "$ANSIBLE_ROOT:/work" -w /work)
ANSIBLE_EXTRA=()
DOCKER_TTY=()
[[ "$NO_TTY" -eq 0 && -t 0 && -t 1 ]] && DOCKER_TTY=(-it)

if [[ -n "$SSH_KEY_PATH" ]]; then
  SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"
  [[ "$SSH_KEY_PATH" != /* ]] && SSH_KEY_PATH="$(cd "$(dirname "$SSH_KEY_PATH")" && pwd)/$(basename "$SSH_KEY_PATH")"
  DOCKER_MOUNTS+=(-v "$SSH_KEY_PATH:/work/.ssh_key_mount:ro")
  ANSIBLE_EXTRA+=(-e ansible_ssh_private_key_file=/work/.ssh_key_mount)
fi
[[ -n "$LIMIT" ]] && ANSIBLE_EXTRA+=(--limit "$LIMIT")

docker run --rm "${DOCKER_TTY[@]}" \
  "${DOCKER_MOUNTS[@]}" \
  --network host \
  -e ANSIBLE_CONFIG=/work/ansible.cfg \
  -e ANSIBLE_ROLES_PATH=/work/roles \
  "$ANSIBLE_IMAGE" \
  ansible-playbook -i "/work/$INV" \
  "${TAGS[@]}" \
  "${ANSIBLE_EXTRA[@]}" \
  "${EXTRA[@]}" \
  playbooks/prepare_servers.yml
