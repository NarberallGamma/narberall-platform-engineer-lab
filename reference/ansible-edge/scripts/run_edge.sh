#!/usr/bin/env bash
# Run xui_docker via ansible-runner. Execute from reference/ansible-edge/.
set -euo pipefail

ANSIBLE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ANSIBLE_ROOT"

ANSIBLE_IMAGE="${ANSIBLE_IMAGE:-example/ansible-runner:1.1}"
IMAGE_PULL_POLICY="${IMAGE_PULL_POLICY:-auto}"
INV="inventories/hosts.ini"
PROFILE=""
SSH_KEY_PATH=""
USE_SSH_AGENT=0
FORCE_TTY=0
NO_TTY=0
EXTRA=()

usage() {
  cat <<'EOF'
Usage: run_edge.sh --main|--jump|--proxy [options] [-- ansible-playbook args...]

  --main              playbooks/xui_main.yml   (group [xui_main])
  --jump, --proxy     playbooks/xui_proxy.yml  (group [xui_proxy])
  --limit HOST        pass through to ansible-playbook
  -k, --ssh-key PATH  private key mounted into the runner
  --ssh-agent         use SSH_AUTH_SOCK
  --pull / --no-pull  ansible-runner image
  --image TAG         ansible-runner image
  --tty / --no-tty    docker run TTY ( --no-tty for CI / non-interactive )
  --tags TAGS         Ansible tags (ufw, ssl, compose, panel, xray, routing, ssh_tunnel, scheduled_restart)
  --skip-tags TAGS

Examples:
  ./scripts/run_edge.sh --jump --limit jump-1.example.com
  ./scripts/run_edge.sh --main --tags compose
  ./scripts/run_edge.sh --jump --tags routing -e xui_routing_outbound_tag=outbound-vless-eu-1
  ./scripts/run_edge.sh --jump --tags ssh_tunnel --no-tty
EOF
}

LIMIT=""
TAGS=()
SKIP_TAGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --main)       PROFILE=main; shift ;;
    --jump|--proxy) PROFILE=proxy; shift ;;
    --limit)      LIMIT="$2"; shift 2 ;;
    --ssh-key|-k) SSH_KEY_PATH="$2"; shift 2 ;;
    --ssh-agent)  USE_SSH_AGENT=1; shift ;;
    --pull)       IMAGE_PULL_POLICY=pull; shift ;;
    --no-pull)    IMAGE_PULL_POLICY=local; shift ;;
    --image)      ANSIBLE_IMAGE="$2"; shift 2 ;;
    --tty)        FORCE_TTY=1; shift ;;
    --no-tty)     NO_TTY=1; shift ;;
    --tags)       TAGS=(--tags "$2"); shift 2 ;;
    --skip-tags)  SKIP_TAGS=(--skip-tags "$2"); shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    --)           shift; EXTRA+=("$@"); break ;;
    *)            EXTRA+=("$1"); shift ;;
  esac
done

if [[ -z "$PROFILE" ]]; then
  echo "run_edge.sh: pass --main or --jump/--proxy" >&2
  usage >&2
  exit 1
fi

if [[ "$FORCE_TTY" -eq 1 && "$NO_TTY" -eq 1 ]]; then
  echo "run_edge.sh: --tty and --no-tty are incompatible" >&2
  exit 1
fi

PLAYBOOK="playbooks/xui_${PROFILE}.yml"

ensure_ansible_image() {
  if docker image inspect "$ANSIBLE_IMAGE" &>/dev/null; then
    echo "ansible-runner (local): $ANSIBLE_IMAGE"
    return 0
  fi
  case "$IMAGE_PULL_POLICY" in
    pull|auto)
      echo "Image $ANSIBLE_IMAGE missing locally, pull..."
      docker pull "$ANSIBLE_IMAGE"
      ;;
    local)
      echo "run_edge.sh: image $ANSIBLE_IMAGE not found. Build: ../utilities/ansible-runner/" >&2
      exit 1
      ;;
  esac
}

if ! command -v docker &>/dev/null; then
  echo "run_edge.sh: docker not found." >&2
  exit 1
fi

ensure_ansible_image

DOCKER_MOUNTS=(-v "$ANSIBLE_ROOT:/work" -w /work)
ANSIBLE_EXTRA=()
DOCKER_ENV=()
DOCKER_TTY=()

if [[ "$NO_TTY" -eq 0 && ( "$FORCE_TTY" -eq 1 || ( -t 0 && -t 1 ) ) ]]; then
  DOCKER_TTY=(-it)
fi

if [[ "$USE_SSH_AGENT" -eq 1 ]]; then
  [[ -z "${SSH_AUTH_SOCK:-}" ]] && { echo "run_edge.sh: SSH_AUTH_SOCK is required" >&2; exit 1; }
  DOCKER_MOUNTS+=(-v "$SSH_AUTH_SOCK:$SSH_AUTH_SOCK")
  DOCKER_ENV+=(-e "SSH_AUTH_SOCK=$SSH_AUTH_SOCK")
  ANSIBLE_EXTRA+=(-e ansible_ssh_private_key_file= -e ansible_ssh_common_args='')
elif [[ -n "$SSH_KEY_PATH" ]]; then
  SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"
  [[ "$SSH_KEY_PATH" != /* ]] && SSH_KEY_PATH="$(cd "$(dirname "$SSH_KEY_PATH")" && pwd)/$(basename "$SSH_KEY_PATH")"
  DOCKER_MOUNTS+=(-v "$SSH_KEY_PATH:/work/.ssh_key_mount:ro")
  ANSIBLE_EXTRA+=(-e ansible_ssh_private_key_file=/work/.ssh_key_mount)
fi

[[ -n "$LIMIT" ]] && ANSIBLE_EXTRA+=(--limit "$LIMIT")

docker run --rm "${DOCKER_TTY[@]}" \
  "${DOCKER_MOUNTS[@]}" \
  "${DOCKER_ENV[@]}" \
  --network host \
  -e ANSIBLE_CONFIG=/work/ansible.cfg \
  -e ANSIBLE_ROLES_PATH=/work/roles \
  "$ANSIBLE_IMAGE" \
  ansible-playbook -i "/work/$INV" \
  "${TAGS[@]}" \
  "${SKIP_TAGS[@]}" \
  "${ANSIBLE_EXTRA[@]}" \
  "${EXTRA[@]}" \
  "$PLAYBOOK"
