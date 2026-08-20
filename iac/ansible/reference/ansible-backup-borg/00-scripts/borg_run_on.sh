#!/usr/bin/env bash

SSH_DISABLE_CONTROL_OPTIONS="-o ControlPath=none -o ControlMaster=no"
SSH_OPTIONS="-o StrictHostKeyChecking=no -o ConnectionAttempts=3 ${SSH_DISABLE_CONTROL_OPTIONS}"

export BORG_RSH="ssh ${SSH_DISABLE_CONTROL_OPTIONS}"

BACKUP_USER="borg"

################################################################################

# Отправляет алерт
# ${1} - if equal 'under_sudo' then try run alerting CLI under sudo, otherwise - without sudo
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
SCRIPT="${SCRIPTSDIR}/${2}"
SCRIPT_NAME="${2}"
SCRIPT_ARGS="${3}"

UNDER_KUBERNETES="${WORKDIR}/../UNDER_KUBERNETES"

SSH_KEY='/root/.ssh/.borg'
if test ! -f "${UNDER_KUBERNETES}";
then
  SSH_KEY="${HOME}/.ssh/.borg-${PROJECT}"
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

# Description:
# 1) Copy bash scripts to client host
# 2) SSH to borg storage server to fill .ssh/known_hosts on client host
# 3) Run the required script from 00-scripts dir
BACKUP_COMMAND_LINE="
  set -e

  ssh-add '${SSH_KEY}'

  echo '### Fill known_hosts'
  ssh ${SSH_OPTIONS} ${PROXY_OPTION} '${BACKUP_USER}@${TARGET_HOST}' -p '${TARGET_PORT:-22}' 'hostname'

  echo '### SCP repo'
  scp ${SSH_DISABLE_CONTROL_OPTIONS} ${PROXY_OPTION} -P '${TARGET_PORT:-22}' -r '${WORKDIR}' '${WORKDIR}/../vars' '${BACKUP_USER}@${TARGET_HOST}:.'

  echo '### Add execution rights for scripts'
  ssh ${SSH_OPTIONS} ${PROXY_OPTION} '${BACKUP_USER}@${TARGET_HOST}' -p '${TARGET_PORT:-22}' 'chmod -R +x ./${SCRIPTSDIR}/'

  echo '### Run borg_install.sh'
  ssh -A ${SSH_OPTIONS} ${PROXY_OPTION} '${BACKUP_USER}@${TARGET_HOST}' -p '${TARGET_PORT:-22}' 'sudo ${SCRIPTSDIR}/borg_install.sh'

  echo '### Optional alerting CLI (backup_notify), if present on the target'
  ssh -A ${SSH_OPTIONS} ${PROXY_OPTION} '${BACKUP_USER}@${TARGET_HOST}' -p '${TARGET_PORT:-22}' 'command -v backup_notify >/dev/null || true'

  echo '### Fill known_hosts'
  ssh -A ${SSH_OPTIONS} ${PROXY_OPTION} '${BACKUP_USER}@${TARGET_HOST}' -p '${TARGET_PORT:-22}' 'sudo -E ssh ${SSH_OPTIONS} \"${BORG_SERVER}\" \"borg -V\"'

  echo '### Run script'
  ssh -A ${SSH_OPTIONS} ${PROXY_OPTION} '${BACKUP_USER}@${TARGET_HOST}' -p '${TARGET_PORT:-22}' 'sudo -E \"${SCRIPT}\" ${SCRIPT_ARGS}'
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
