#!/usr/bin/env bash
# Wait for estate/ansible main sync to /ansible, then deploy allowlisted docker-apps.
# Modes:
#   wait   : poll ansible project pipeline success after cutover merge
#   deploy : run run_docker_app.sh for apps in prod-ansible-vm-apps.txt
# Optional: ANSIBLE_VM_APP=<slug> to deploy a single app from the manifest.
set -euo pipefail

# shellcheck source=release_lib.sh
source "$(dirname "$0")/release_lib.sh"

MODE="${1:-}"
ANSIBLE_REPO_PATH="${ANSIBLE_REPO_DEPLOY_PATH:-/ansible}"
ANSIBLE_PROJECT_PATH="${ANSIBLE_PROJECT_PATH:-estate/ansible}"
ANSIBLE_SYNC_TIMEOUT_SEC="${ANSIBLE_SYNC_TIMEOUT_SEC:-1200}"
ANSIBLE_SYNC_POLL_SEC="${ANSIBLE_SYNC_POLL_SEC:-15}"
ANSIBLE_REPO_CHOWN_UID="${ANSIBLE_REPO_CHOWN_UID:-1001}"
ANSIBLE_REPO_CHOWN_GID="${ANSIBLE_REPO_CHOWN_GID:-1001}"

manifest_path() {
  local candidates=(
    "${CI_PROJECT_DIR:-}/releases/manifests/prod-ansible-vm-apps.txt"
    "$(dirname "$0")/../manifests/prod-ansible-vm-apps.txt"
  )
  local p
  for p in "${candidates[@]}"; do
    if [[ -f "$p" ]]; then
      echo "$p"
      return 0
    fi
  done
  echo "ERROR: prod-ansible-vm-apps.txt not found" >&2
  exit 2
}

b64_decode_ci_var() {
  local raw="$1" pad n
  raw=$(printf '%s' "$raw" | tr -d '\n=')
  n=${#raw}
  pad=$(( (4 - n % 4) % 4 ))
  case $pad in
    1) raw="${raw}=" ;;
    2) raw="${raw}==" ;;
    3) raw="${raw}===" ;;
  esac
  printf '%s' "$raw" | base64 -d
}

materialize_ssh_keys() {
  local dest="$1"
  mkdir -p "${dest}/.ssh"
  local wrote=0
  if [[ -n "${ANSIBLE_SSH_PRIVATE_KEY_B64:-}" ]]; then
    b64_decode_ci_var "${ANSIBLE_SSH_PRIVATE_KEY_B64}" > "${dest}/.ssh/ansible_ssh_key"
    printf '\n' >> "${dest}/.ssh/ansible_ssh_key"
    wrote=1
    echo "OK wrote ${dest}/.ssh/ansible_ssh_key from ANSIBLE_SSH_PRIVATE_KEY_B64"
  fi
  if [[ -n "${GITLAB_RUNNER_SSH_PRIVATE_KEY_B64:-}" ]]; then
    b64_decode_ci_var "${GITLAB_RUNNER_SSH_PRIVATE_KEY_B64}" > "${dest}/.ssh/gitlab_runner_ssh_key"
    printf '\n' >> "${dest}/.ssh/gitlab_runner_ssh_key"
    wrote=1
    echo "OK wrote ${dest}/.ssh/gitlab_runner_ssh_key from GITLAB_RUNNER_SSH_PRIVATE_KEY_B64"
  fi
  if [[ "$wrote" -eq 1 ]]; then
    chmod 700 "${dest}/.ssh"
    chmod 600 "${dest}/.ssh/"* 2>/dev/null || true
    chown -R "${ANSIBLE_REPO_CHOWN_UID}:${ANSIBLE_REPO_CHOWN_GID}" "${dest}/.ssh" || true
  else
    echo "INFO: no SSH key CI vars; using keys already present under ${dest}/.ssh (from ansible sync)"
  fi
}

ansible_project_id() {
  local enc
  enc="$(release_urlencode "$ANSIBLE_PROJECT_PATH")"
  release_api GET "/projects/${enc}" | jq -r '.id'
}

assert_ansible_workdir() {
  if [[ ! -d "$ANSIBLE_REPO_PATH" ]]; then
    echo "ERROR: ${ANSIBLE_REPO_PATH} missing on runner" >&2
    exit 1
  fi
  if [[ ! -f "${ANSIBLE_REPO_PATH}/scripts/run/run_docker_app.sh" ]]; then
    echo "ERROR: ${ANSIBLE_REPO_PATH}/scripts/run/run_docker_app.sh missing after sync" >&2
    exit 1
  fi
}

# If an ansible MR was merged for the active release, require a main pipeline created at/after that merge.
ansible_release_merged_at() {
  release_require_current_branch
  local merged needle
  merged="$(release_list_merged_release_mrs "$RELEASE_CURRENT_BRANCH" || true)"
  if [[ -z "$merged" || "$merged" == "null" ]]; then
    echo ""
    return 0
  fi
  needle="/${ANSIBLE_PROJECT_PATH}/"
  echo "$merged" | jq -r --arg needle "$needle" '
    [.[] | select((.web_url // "") | contains($needle)) | .merged_at // empty]
    | map(select(length > 0))
    | if length == 0 then "" else max end
  '
}

iso_to_epoch() {
  # GitLab timestamps: 2026-08-12T10:00:00.000Z; strip fractional seconds for jq
  local ts="${1:-}"
  [[ -z "$ts" ]] && { echo 0; return 0; }
  ts="$(printf '%s' "$ts" | sed -E 's/\.[0-9]+Z$/Z/')"
  jq -nr --arg t "$ts" '$t | fromdateiso8601' 2>/dev/null || echo 0
}

wait_ansible_sync() {
  release_log_header "ansible_vm_deploy_release.sh wait"
  release_require_token
  release_require_current_branch

  local project_id merged_at merged_epoch
  project_id="$(ansible_project_id)"
  merged_at="$(ansible_release_merged_at)"
  merged_epoch=0
  if [[ -n "$merged_at" ]]; then
    merged_epoch="$(iso_to_epoch "$merged_at")"
  fi
  echo "ansible_project=${ANSIBLE_PROJECT_PATH} id=${project_id}"
  echo "release_branch=${RELEASE_CURRENT_BRANCH}"
  echo "ansible_mr_merged_at=${merged_at:-<none in this release>}"
  echo "timeout_sec=${ANSIBLE_SYNC_TIMEOUT_SEC} poll_sec=${ANSIBLE_SYNC_POLL_SEC}"

  local started_at deadline now status pipeline_id web_url created_at created_epoch
  started_at="$(date -u +%s)"
  deadline=$((started_at + ANSIBLE_SYNC_TIMEOUT_SEC))

  while true; do
    now="$(date -u +%s)"
    if [[ "$now" -ge "$deadline" ]]; then
      echo "ERROR: timed out waiting for ansible main pipeline success (${ANSIBLE_SYNC_TIMEOUT_SEC}s)" >&2
      exit 1
    fi

    local pipelines
    pipelines="$(release_api GET "/projects/${project_id}/pipelines?ref=main&per_page=5")"
    pipeline_id="$(echo "$pipelines" | jq -r '.[0].id // empty')"
    status="$(echo "$pipelines" | jq -r '.[0].status // empty')"
    web_url="$(echo "$pipelines" | jq -r '.[0].web_url // empty')"
    created_at="$(echo "$pipelines" | jq -r '.[0].created_at // empty')"
    created_epoch=0
    [[ -n "$created_at" ]] && created_epoch="$(iso_to_epoch "$created_at")"

    if [[ -z "$pipeline_id" ]]; then
      echo "WAIT: no pipelines on ansible main yet..."
      sleep "${ANSIBLE_SYNC_POLL_SEC}"
      continue
    fi

    echo "pipeline=#${pipeline_id} status=${status} created_at=${created_at} url=${web_url}"

    case "$status" in
      success)
        if [[ "$merged_epoch" -gt 0 && "$created_epoch" -gt 0 && "$created_epoch" -lt "$merged_epoch" ]]; then
          echo "WAIT: latest success pipeline predates ansible MR merge (${created_at} < ${merged_at}); waiting for post-merge sync..."
          sleep "${ANSIBLE_SYNC_POLL_SEC}"
          continue
        fi
        assert_ansible_workdir
        echo "OK ansible sync ready at ${ANSIBLE_REPO_PATH}"
        return 0
        ;;
      failed|canceled|cancelled|skipped)
        if [[ "$merged_epoch" -gt 0 && "$created_epoch" -gt 0 && "$created_epoch" -lt "$merged_epoch" ]]; then
          echo "WAIT: stale ${status} pipeline before merge; waiting for new pipeline..."
          sleep "${ANSIBLE_SYNC_POLL_SEC}"
          continue
        fi
        echo "ERROR: ansible main pipeline #${pipeline_id} ended with status=${status}" >&2
        echo "Fix sync in ${web_url} then re-run this job." >&2
        exit 1
        ;;
      *)
        echo "WAIT: ansible pipeline still ${status}..."
        sleep "${ANSIBLE_SYNC_POLL_SEC}"
        ;;
    esac
  done
}

deploy_apps() {
  release_log_header "ansible_vm_deploy_release.sh deploy"

  if [[ ! -d "$ANSIBLE_REPO_PATH" ]]; then
    echo "ERROR: ansible workdir missing: ${ANSIBLE_REPO_PATH}" >&2
    exit 2
  fi
  if [[ ! -x "${ANSIBLE_REPO_PATH}/scripts/run/run_docker_app.sh" && ! -f "${ANSIBLE_REPO_PATH}/scripts/run/run_docker_app.sh" ]]; then
    echo "ERROR: run_docker_app.sh not found under ${ANSIBLE_REPO_PATH}" >&2
    exit 2
  fi

  materialize_ssh_keys "$ANSIBLE_REPO_PATH"

  if [[ ! -f "${ANSIBLE_REPO_PATH}/.ssh/ansible_ssh_key" ]]; then
    echo "ERROR: ${ANSIBLE_REPO_PATH}/.ssh/ansible_ssh_key missing (sync SSH keys or set ANSIBLE_SSH_PRIVATE_KEY_B64)" >&2
    exit 2
  fi

  local mf app limit filter="${ANSIBLE_VM_APP:-}"
  mf="$(manifest_path)"
  echo "manifest=${mf}"
  if [[ -n "$filter" ]]; then
    echo "filter ANSIBLE_VM_APP=${filter}"
  fi

  local deployed=0
  while read -r app limit || [[ -n "${app:-}" ]]; do
    [[ -z "${app:-}" || "$app" =~ ^# ]] && continue
    # allow "app host" or whitespace-separated
    if [[ -z "${limit:-}" ]]; then
      echo "ERROR: bad manifest line (need app_slug limit_host): ${app}" >&2
      exit 2
    fi
    if [[ -n "$filter" && "$app" != "$filter" ]]; then
      echo "SKIP ${app} (filter=${filter})"
      continue
    fi
    echo "=== deploy ${app} --prod --limit ${limit} ==="
    (
      cd "$ANSIBLE_REPO_PATH"
      chmod +x scripts/run/run_docker_app.sh 2>/dev/null || true
      ./scripts/run/run_docker_app.sh deploy "$app" --prod --limit "$limit"
    )
    echo "OK deployed ${app}"
    deployed=$((deployed + 1))
  done < <(grep -vE '^\s*(#|$)' "$mf" | awk '{print $1, $2}')

  if [[ "$deployed" -eq 0 ]]; then
    if [[ -n "$filter" ]]; then
      echo "ERROR: ANSIBLE_VM_APP=${filter} not found in manifest ${mf}" >&2
    else
      echo "ERROR: no apps deployed from manifest ${mf}" >&2
    fi
    exit 2
  fi
  echo "OK ansible VM deploy complete (apps=${deployed})"
}

case "$MODE" in
  wait)
    wait_ansible_sync
    ;;
  deploy)
    deploy_apps
    ;;
  *)
    echo "Usage: $0 wait|deploy" >&2
    exit 2
    ;;
esac
