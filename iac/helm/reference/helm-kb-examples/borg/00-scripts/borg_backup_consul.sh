#!/usr/bin/env bash

# Этот скрипт - основной способ бэкапа consul

# Принцип работы:
#   - создание резервной копии consul с помощью команды 'curl http://127.0.0.1:8500/v1/snapshot -o snapshot.tgz'
#   - востановление из бэкапа 'curl --request PUT --data-binary @snapshot.tgz http://127.0.0.1:8500/v1/snapshot'
#
# Поддерживаемые опции:
# -h|--host               - адрес подключения к Consul. Необязательный аргумент
# -r|--port               - порт подключения к Consul. Необязательный аргумент
# -s|--ssl                - протокол подключения к Consul. Необязательный аргумент
# -k|--prune              - строка с опциями алгоритма сохранения резервных копий в
#                           формате программы Borg, например '--keep-hourly 72 --keep-within=30d'
#                           Необязательный аргумент, без указания этой опции будет
#                           использовано значение ${CUSTOMPRUNE_DEFAULT}
# --skip-hostname-prefix  - позволяет исключить из имени Borg-репозитория
#                           префикс '$(hostname)-'. Необязательный аргумент

# Позиционные аргументы:
# ${1} - имя задания, суффикс имени Borg-репозитория, без указания будет
#        использовано имя заданное в ${NAMEOFBACKUP_DEFAULT}

# Примеры использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_consul.sh
# borg_run_on.sh 10.0.0.1 borg_backup_consul.sh 'CONSUL'
# borg_run_on.sh 10.0.0.1 borg_backup_consul.sh 'CONSUL --host 127.0.0.1 --port 8500'
# borg_run_on.sh 10.0.0.1 borg_backup_consul.sh 'CONSUL --prune "--keep-hourly 3 --keep-within=30d"'
# wrapper_ssh-agent.sh borg_backup_consul.sh 'CONSUL --host 10.0.0.1'

################################################################################

source vars

NAMEOFBACKUP_DEFAULT="CONSUL"
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=14d --keep-weekly=4 --keep-monthly=3'
TYPEOFBACKUP="CONSUL"

################################################################################

function alert {
  BACKUP_TARGET=$(hostname)
  BACKUP_TYPE=${NAMEOFBACKUP}
  CLUSTER=${CLUSTER:-unknown}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  printf "%s\n" "ERROR: ${MESSAGE}"
  backup_notify --trigger backup --label cluster="${CLUSTER}" --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

################################################################################

CUSTOMPRUNE=""
HOST="127.0.0.1"
PORT="8500"
ERRLOG=`mktemp`

# Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options h:r:k:s: --longoptions ,host:,port:,prune:,ssl:,skip-hostname-prefix -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -h|--host)                HOST="${2}";         shift 2;;
    -r|--port)                PORT="${2}";         shift 2;;
    -k|--prune)               CUSTOMPRUNE="${2}";  shift 2;;
    -s|--ssl)                 USE_SSL="yes";  shift 1;;
    --skip-hostname-prefix)   DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME="yes";  shift 1;;
    *) break ;;
  esac
done

NAMEOFBACKUP="${2}"

if test -z "${NAMEOFBACKUP}";
then
  printf "%s\n" "WARNING: job name is not defined, used default value '${NAMEOFBACKUP_DEFAULT}'"
  NAMEOFBACKUP="${NAMEOFBACKUP_DEFAULT}"
fi

if test "${DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME}" == "yes";
then
  REPOSITORY="${BORG_SERVER}:${NAMEOFBACKUP}"
else
  REPOSITORY="${BORG_SERVER}:$(hostname)-${NAMEOFBACKUP}"
fi

if test "${USE_SSL}" == "yes";
then
  HTTP="https"
else
  HTTP="http"
fi


printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
borg init -e none "${REPOSITORY}"

BACKUP_COMMAND_LINE=\
"curl ${HTTP}://${HOST}:${PORT}/v1/snapshot 2>>$ERRLOG"

BORG_COMMAND_LINE=\
"borg create --show-rc --stats \
'${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' -"

printf "%s\n" "Create backup archive:"

printf "%s\n" "${BACKUP_COMMAND_LINE} | ${BORG_COMMAND_LINE}"
bash -c "${BACKUP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"

CREATE_EXIT=( "${PIPESTATUS[@]}" )

if test "${CREATE_EXIT[0]}" -ne 0;
then
  alert "backup failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped" "`cat $ERRLOG`"
  rm $ERRLOG
  exit 1
fi

if test "${CREATE_EXIT[1]}" -ne 0;
then
  alert "borg create failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped" "`cat $ERRLOG`"
  rm $ERRLOG
  exit 1
fi


PRUNE_COMMAND_LINE=\
"borg prune --show-rc --list '${REPOSITORY}' \
${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}} 2>>$ERRLOG"

printf "%s\n" "Prune old backup archives:"
printf "%s\n" "${PRUNE_COMMAND_LINE}"
printf "%s\n" "${PRUNE_COMMAND_LINE}" | bash

PRUNE_EXIT="${?}"

if test "${PRUNE_EXIT}" -ne 0;
then
  alert "borg prune failed, exit code ${PRUNE_EXIT}" "`cat $ERRLOG`"
  rm $ERRLOG
  exit 1
fi

rm $ERRLOG

exit 0
