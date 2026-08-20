#!/usr/bin/env bash

SSH_DISABLE_CONTROL_OPTIONS="-o ControlPath=none -o ControlMaster=no"
SSH_OPTIONS="-o StrictHostKeyChecking=no ${SSH_DISABLE_CONTROL_OPTIONS}"

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

  if test ! -z "${CLUSTER}";
  then
    additional_labels="${additional_labels} --label 'cluster=${CLUSTER}'"
  fi

  bash -c "${sudo_utility} backup_notify --trigger 'Run of backup script failed' ${additional_labels} --label 'start_point=$( hostname )' --label 'backup_target=${TARGET_STR}' --label 'backup_type=${SCRIPT_NAME} ${SCRIPT_ARGS}' --summary 'This error occurred in the $( basename "${0}" ) script, it may be redundant'"
}

################################################################################

WORKDIR="$( dirname "${0}" )"

source "${WORKDIR}/../vars"

CMD="${*}"
SCRIPT="${1}"

UNDER_KUBERNETES="${WORKDIR}/../UNDER_KUBERNETES"

SSH_KEY='/root/.ssh/.borg'
if test ! -f "${UNDER_KUBERNETES}";
then
  SSH_KEY="${HOME}/.ssh/.borg-${PROJECT}"
fi

BACKUP_COMMAND_LINE="
  set -e

  ssh-add '${SSH_KEY}'

  echo '### Add execution rights for scripts'
  chmod +x '${SCRIPT}'

  echo '### Fill known_hosts'
  ssh ${SSH_OPTIONS} '${BORG_SERVER}' 'hostname'

  cd '${WORKDIR}/../'

  ${CMD} --skip-hostname-prefix
"

if test ! -f "${UNDER_KUBERNETES}";
then
  echo "Start backup ${CMD}" | logger -sit "backup_schedule"

  ssh-agent bash -c "${BACKUP_COMMAND_LINE}" 2>&1 | logger -sit "backup_schedule"
  BACKUP_EXIT=( "${PIPESTATUS[@]}" )
  if test "${BACKUP_EXIT[0]}" -ne 0;
  then
    alert "under_sudo"
  fi

  echo "End backup ${CMD}" | logger -sit "backup_schedule"
else
  echo "Start backup ${CMD}"

  ssh-agent bash -c "${BACKUP_COMMAND_LINE}"
  if test "${?}" -ne 0;
  then
    alert
  fi

  echo "End backup ${CMD}"
fi

