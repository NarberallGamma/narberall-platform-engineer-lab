#!/usr/bin/env bash
# Control-node /ansible environment after a GitLab CI deploy.
# Call after docker_ssh_apply in run scripts (cwd = ansible repo root).
#
# - source .env.vault (VAULT_ADDR, VAULT_TOKEN from CI Variables)
# - auto-attach .ssh/ansible_ssh_key + ansible_user=ansible (inventory [all:vars] root)
#   when --ssh-key / --ssh-agent / --ask-pass is not set
# - pass VAULT_* into the ansible container

control_node_env_apply() {
  if [[ -f .env.vault ]]; then
    # shellcheck disable=SC1091
    source .env.vault
  fi

  if [[ -n "${VAULT_ADDR:-}" ]]; then
    DOCKER_ENV+=(-e "VAULT_ADDR=${VAULT_ADDR}")
  fi
  if [[ -n "${VAULT_TOKEN:-}" ]]; then
    DOCKER_ENV+=(-e "VAULT_TOKEN=${VAULT_TOKEN}")
  fi

  if [[ -z "${SSH_KEY_PATH:-}" && -z "${USE_SSH_AGENT:-}" && -z "${ASK_PASS:-}" && -f .ssh/ansible_ssh_key ]]; then
    DOCKER_MOUNTS+=(-v "$(pwd)/.ssh:/work/.ssh:ro")
    ANSIBLE_EXTRA+=(
      -e ansible_ssh_private_key_file=/work/.ssh/ansible_ssh_key
      -e ansible_private_key_file=/work/.ssh/ansible_ssh_key
      -e ansible_user=ansible
    )
  fi
}
