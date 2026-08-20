#!/usr/bin/env bash
# GitLab PAT для estate (HTTPS clone/fetch/push). Без source всего .env-estate (там PostgreSQL и Keycloak).
#
# Источник: ~/.config/ops/.env-cloud (legacy symlink ~/scripts/cr/.env)
# Переопределение: GIT_ENV_FILE=/path/to/.env-estate
#
# Ключи: PROD_GITLAB_TOKEN, PREPROD_GITLAB_TOKEN

_git_read_env_var() {
  local file="$1"
  local key="$2"
  local line value
  line="$(grep -E "^${key}=" "$file" 2>/dev/null | tail -1 || true)"
  [[ -z "$line" ]] && return 0
  value="${line#*=}"
  value="${value%$'\r'}"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  printf '%s' "$value"
}

load_git_env() {
  local env_file="${GIT_ENV_FILE:-${HOME}/.config/ops/.env-cloud}"
  if [[ ! -f "$env_file" && -f "$HOME/scripts/cr/.env" ]]; then
    env_file="$HOME/scripts/cr/.env"
  fi
  if [[ ! -f "$env_file" ]]; then
    return 0
  fi

  local prod pre
  prod="$(_git_read_env_var "$env_file" PROD_GITLAB_TOKEN)"
  pre="$(_git_read_env_var "$env_file" PREPROD_GITLAB_TOKEN)"

  export GITLAB_TOKEN_PROD="${GITLAB_TOKEN_PROD:-$prod}"
  export GITLAB_TOKEN_PREPROD="${GITLAB_TOKEN_PREPROD:-$pre}"
}

load_git_env
