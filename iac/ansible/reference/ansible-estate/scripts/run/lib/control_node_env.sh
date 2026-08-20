#!/usr/bin/env bash
# Окружение контрол-ноды /ansible после деплоя из GitLab CI.
# Вызывать после docker_ssh_apply в run-скриптах (cwd = корень репо ansible).
#
# - source .env.vault (VAULT_ADDR, VAULT_TOKEN из CI Variables)
# - автоподключение .ssh/ansible_ssh_key + ansible_user=ansible (inventory [all:vars] root)
#   если не задан --ssh-key / --ssh-agent / --ask-pass
# - проброс VAULT_* в контейнер ansible

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
