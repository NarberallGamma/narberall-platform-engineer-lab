#!/usr/bin/env bash
# HTTPS auth и URL для GitLab estate (gitlab.example.invalid / gitlab.preprod.example.invalid).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=load_git_env.sh
source "$SCRIPT_DIR/load_git_env.sh"

_gitlab_host() {
  local env="$1"
  case "$env" in
    PROD) printf '%s' "${GITLAB_HOST_PROD:-gitlab.example.invalid}" ;;
    PREPROD) printf '%s' "${GITLAB_HOST_PREPROD:-gitlab.preprod.example.invalid}" ;;
    *)
      echo "git_https: unknown env $env (PROD|PREPROD)" >&2
      return 1
      ;;
  esac
}

gitlab_token_for_env() {
  local env="$1"
  local var="GITLAB_TOKEN_${env}"
  printf '%s' "${!var:-}"
}

git_https_origin_url() {
  local env="$1"
  local repo_name="$2"
  local host
  host="$(_gitlab_host "$env")"
  printf 'https://%s/%s/%s.git' "$host" "${GITLAB_GROUP:-ops}" "$repo_name"
}

_git_askpass_file=""
_git_askpass_token=""

git_https_cleanup_askpass() {
  if [[ -n "${_git_askpass_file:-}" && -f "$_git_askpass_file" ]]; then
    rm -f "$_git_askpass_file"
  fi
  _git_askpass_file=""
  unset GIT_ASKPASS GIT_TERMINAL_PROMPT 2>/dev/null || true
  unset _git_askpass_token 2>/dev/null || true
}

# Подготовить GIT_ASKPASS (oauth2 + PAT). Вызвать git_https_cleanup_askpass после git.
git_https_prepare_auth() {
  local env="$1"
  local token
  token="$(gitlab_token_for_env "$env")"
  if [[ -z "$token" ]]; then
    echo "git_https: GITLAB_TOKEN_${env} not set (~/.config/ops/.env-cloud)" >&2
    return 1
  fi

  git_https_cleanup_askpass
  _git_askpass_token="$token"
  _git_askpass_file="$(mktemp)"
  chmod 700 "$_git_askpass_file"
  printf '#!/bin/sh\necho "%s"\n' "$token" >"$_git_askpass_file"
  export GIT_ASKPASS="$_git_askpass_file"
  export GIT_TERMINAL_PROMPT=0
}

# SSH remote -> canonical HTTPS без токена в URL
git_ssh_remote_to_https() {
  local url="$1"
  local host path
  if [[ "$url" =~ ^git@([^:]+):(.+)\.git$ ]]; then
    host="${BASH_REMATCH[1]}"
    path="${BASH_REMATCH[2]}"
    printf 'https://%s/%s.git' "$host" "$path"
    return 0
  fi
  if [[ "$url" =~ ^https://([^/]+)/(.+)\.git$ ]]; then
    host="${BASH_REMATCH[1]}"
    path="${BASH_REMATCH[2]}"
    printf 'https://%s/%s.git' "$host" "$path"
    return 0
  fi
  return 1
}

git_env_from_remote_url() {
  local url="$1"
  if [[ "$url" == *gitlab.preprod.example.invalid* ]]; then
    printf 'PREPROD'
  elif [[ "$url" == *gitlab.example.invalid* ]]; then
    printf 'PROD'
  else
    return 1
  fi
}

ensure_origin_https_sanitized() {
  local repo_path="$1"
  local url https
  url="$(git -C "$repo_path" remote get-url origin 2>/dev/null || true)"
  [[ -n "$url" ]] || return 1
  if ! https="$(git_ssh_remote_to_https "$url")"; then
    return 1
  fi
  if [[ "$url" != "$https" ]]; then
    git -C "$repo_path" remote set-url origin "$https"
  fi
}
