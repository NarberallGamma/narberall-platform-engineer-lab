#!/usr/bin/env bash

SSH_DISABLE_CONTROL_OPTIONS="-o ControlPath=none -o ControlMaster=no"
SSH_OPTIONS="-o StrictHostKeyChecking=no ${SSH_DISABLE_CONTROL_OPTIONS}"

BACKUP_USER="restic"

################################################################################

# Отправляет алерт
# ${1} - if equal 'under_sudo' then try run backup_notify under sudo, otherwise - without sudo
alert()
{
  local start_point_project
  local sudo_utility
  local additional_labels

  start_point_project="$( backup_notify --print-env | sed --quiet "/^[ \t]*PROJECT[ \t]*=[ \t]*/{s/^[ \t]*PROJECT[ \t]*=[ \t]*\(.*\)$/\1/;p}" )"

  sudo_utility=""
  additional_labels=""

  if test "${1}" == "under_sudo";
  then
    sudo_utility="sudo"
  fi

  if test "${start_point_project}" != "${PROJECT}";
  then
    additional_labels="--label 'target_project=${PROJECT}'"
  fi

  bash -c "${sudo_utility} backup_notify --trigger 'Run of backup script failed' ${additional_labels} --label 'start_point=$( hostname )' --label 'backup_target=${TARGET_STR}' --label 'backup_type=${SCRIPT_NAME} ${SCRIPT_ARGS}' --summary 'This error occurred in the $( basename "${0}" ) script, it may be redundant'"
}

################################################################################

WORKDIR="$( dirname "${0}" )"
SCRIPTSDIR="$( basename "${WORKDIR}" )"

source "${WORKDIR}/../vars"

TARGET_STR="${1}"
BUCKET="${2}"
SCRIPT="${SCRIPTSDIR}/${3}"
SCRIPT_NAME="${3}"
SCRIPT_ARGS="${4}"

UNDER_KUBERNETES="${WORKDIR}/../UNDER_KUBERNETES"

SSH_KEY='/root/.ssh/.restic'
if test ! -f "${UNDER_KUBERNETES}";
then
  SSH_KEY="${HOME}/.ssh/.restic-${PROJECT}"
fi

TARGET_HOST="$( echo "${TARGET_STR}" | awk -F':' '{print $1}' )"
TARGET_PORT="$( echo "${TARGET_STR}" | awk -F':' '{print $2}' )"
PROXY_HOST="$(  echo "${TARGET_STR}" | awk -F':' '{print $3}' )"
PROXY_PORT="$(  echo "${TARGET_STR}" | awk -F':' '{print $4}' )"

PROXY_OPTION=""
if test -n "${PROXY_HOST}";
then
  PROXY_OPTION="-o ProxyCommand='ssh ${SSH_OPTIONS} \"${BACKUP_USER}@${PROXY_HOST}\" -p \"${PROXY_PORT:-22}\" -W %h:%p'"
fi

restic_repository_var="RESTIC_REPOSITORY_${BUCKET}"
restic_password_var="RESTIC_PASSWORD_${BUCKET}"
aws_access_key_id_var="AWS_ACCESS_KEY_ID_${BUCKET}"
aws_secret_access_key="AWS_SECRET_ACCESS_KEY_${BUCKET}"

EXPORT="export RESTIC_REPOSITORY=${!restic_repository_var}; \
	export RESTIC_PASSWORD=${!restic_password_var}; \
	export AWS_ACCESS_KEY_ID=${!aws_access_key_id_var}; \
	export AWS_SECRET_ACCESS_KEY=${!aws_secret_access_key}; \
  export MONGO_PASSWORD=${MONGO_PASSWORD}; \
  export GOGC=1;"

# Description:
# 1) Copy bash scripts to client host
# 2) Run the required script from 00-scripts dir
BACKUP_COMMAND_LINE="
  set -e

  ssh-add '${SSH_KEY}'

  echo '### Fill known_hosts'
  ssh ${SSH_OPTIONS} ${PROXY_OPTION} '${BACKUP_USER}@${TARGET_HOST}' -p '${TARGET_PORT:-22}' 'hostname'

  echo '### SCP repo'
  scp ${SSH_DISABLE_CONTROL_OPTIONS} ${PROXY_OPTION} -P '${TARGET_PORT:-22}' -r '${WORKDIR}' '${WORKDIR}/../vars' '${BACKUP_USER}@${TARGET_HOST}:.'

  echo '### Add execution rights for scripts'
  ssh ${SSH_OPTIONS} ${PROXY_OPTION} '${BACKUP_USER}@${TARGET_HOST}' -p '${TARGET_PORT:-22}' 'chmod -R +x ./${SCRIPTSDIR}/'

  echo '### Run restic_install.sh'
  ssh -A ${SSH_OPTIONS} ${PROXY_OPTION} '${BACKUP_USER}@${TARGET_HOST}' -p '${TARGET_PORT:-22}' 'sudo ${SCRIPTSDIR}/restic_install.sh'

  echo '### Optional alerting CLI (backup_notify), if present on the target'
  ssh -A ${SSH_OPTIONS} ${PROXY_OPTION} '${BACKUP_USER}@${TARGET_HOST}' -p '${TARGET_PORT:-22}' 'command -v backup_notify >/dev/null || true'

  echo '### Run script'
  ssh -A ${SSH_OPTIONS} ${PROXY_OPTION} '${BACKUP_USER}@${TARGET_HOST}' -p '${TARGET_PORT:-22}' '${EXPORT} sudo -E \"${SCRIPT}\" ${SCRIPT_ARGS}'
"

if test ! -f "${UNDER_KUBERNETES}";
then
  echo "Start backup ${TARGET_STR} ${SCRIPT_NAME} ${SCRIPT_ARGS}" | logger -sit "backup_schedule_${TARGET_STR}"

  ssh-agent bash -c "${BACKUP_COMMAND_LINE}" 2>&1 | logger -sit "backup_schedule_${TARGET_STR}"
  BACKUP_EXIT=( "${PIPESTATUS[@]}" )
  if test "${BACKUP_EXIT[0]}" -ne 0;
  then
    alert "under_sudo"
  fi

  echo "End backup ${TARGET_STR} ${SCRIPT_NAME} ${SCRIPT_ARGS}" | logger -sit "backup_schedule_${TARGET_STR}"
else
  echo "Start backup ${TARGET_STR} ${SCRIPT_NAME} ${SCRIPT_ARGS}"

  ssh-agent bash -c "${BACKUP_COMMAND_LINE}"
  if test "${?}" -ne 0;
  then
    alert
  fi

  echo "End backup ${TARGET_STR} ${SCRIPT_NAME} ${SCRIPT_ARGS}"
fi
