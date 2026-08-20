#!/usr/bin/env bash

# Этот скрипт - делает бэкап содержимого pvc у pod

# Принцип работы:
#   - создание tar бэкапа файлов и/или каталогов в borg-репозитории с помощью
#     'borg create'
#   - удаление старых бэкапов в borg-репозитории с помощью 'borg prune'

# Поддерживаемые опции:
# -q|--add-quoted                - путь к файлу или каталогу который необходимо
#                                  зарезервировать. Опция может быть указана несколько раз, в
#                                  резервную копию попадут все указанные файлы и/или каталоги.
#                                  Указанные пути будут помещены в одинарные кавычки - будут
#                                  корректно обработаны пути с пробелами, но не будут работать
#                                  wildcard-подстановки. Необязательный аргумент если не указан читаются все pvc в pod
# -x|--exclude                   - паттерн для исключения файлов. Необязательный аргумент
# -n|--namespace                 - namespace в кластере. Обязательный аргумент.
# -p|--pod                       - префик либо полное имя пода для подключения. Обязательный аргумент.
# -c|--container                 - Имя контейнера в поде. Необязательный аргумент.
#    --context                   - Контект в конфиг файле kube. Необязательный аргумент.
# -k|--prune                     - строка с опциями алгоритма сохранения резервных копий в
#                                  формате программы Borg, например '--keep-hourly 72 --keep-within=30d'
#                                  Необязательный аргумент, без указания этой опции будет
#                                  использовано значение ${CUSTOMPRUNE_DEFAULT}
#    --prefix                    - строка, помещаемая перед именем архива через знак '-',
#                                  например 'PG-', 'files-'. Необязательный аргумент, без указания
#                                  этой опции будет использовано значение ${TYPEOFBACKUP_DEFAULT}
#    --skip-hostname-prefix      - позволяет исключить из имени Borg-репозитория
#                                  префикс '$(hostname)-'. Необязательный аргумент

# Позиционные аргументы:
# ${1} - имя задания, суффикс имени Borg-репозитория. Обязательный аргумент

# Примеры использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_kube_pvc.sh 'DATA  -q /app/data,/var -n production -p services-files-0 -c php --prune "--keep-hourly 3 --keep-within=30d"'

################################################################################

source vars

TYPEOFBACKUP_DEFAULT='kube-pvc'
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=14d --keep-weekly=4 --keep-monthly=3'

export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no"

# Путь до конфига kubectl
KUBECONF_FILE="/root/.kube/config"
export KUBECONFIG=${KUBECONF_FILE}
KUBECTL="/opt/deckhouse/bin/kubectl"

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP}"
  CLUSTER=${CLUSTER:-unknown}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  printf "%s\n" "ERROR: ${MESSAGE}"
  backup_notify --trigger backup --label cluster="${CLUSTER}" --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

################################################################################

DIRS_QUOTED=""
CUSTOMPRUNE=""
TYPEOFBACKUP=""
EXCLUDE_PATTERN=""
NAMESPACE=""
POD_PREFIX=""
POD_CONTAINER=""
CONTEXT=""
DONT_IGNORE_MISSING_FILES=""

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options q:n:p:c:k: --longoptions ,add-quoted:,namespace:,pod:,container:,context:,,prune:,prefix:,exclude:,dont-ignore-missing-files,skip-hostname-prefix -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -q|--add-quoted)
                                    if test -z "${DIRS_QUOTED}";
                                    then
                                      if test -n "${2}";
                                      then
                                        DIRS_QUOTED="'${2}'"
                                      fi
                                    else
                                      if test -n "${2}";
                                      then
                                        DIRS_QUOTED="${DIRS_QUOTED} '${2}'"
                                      fi
                                    fi

                                    shift 2;;
    -x|--exclude)                   EXCLUDE_PATTERN="${2}";           shift 2;;
    -n|--namespace)                 NAMESPACE="${2}";                 shift 2;;
    -p|--pod)                       POD_PREFIX="${2}";                shift 2;;
    -c|--container)                 POD_CONTAINER="${2}";             shift 2;;
       --context)                   CONTEXT="${2}";                   shift 2;;
    -k|--prune)                     CUSTOMPRUNE="${2}";               shift 2;;
       --prefix)                    TYPEOFBACKUP="${2}";              shift 2;;
       --dont-ignore-missing-files) DONT_IGNORE_MISSING_FILES="yes";  shift 1;;
       --skip-hostname-prefix)      DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME="yes";  shift 1;;
    *) break ;;
  esac
done

NAMEOFBACKUP="${2}"

if test -z "${NAMEOFBACKUP}";
then
  alert "Backup job name is not defined. Backup will not be created"
  exit 1
fi

if test -z "${NAMESPACE}";
then
  alert "Backup job namespace is not defined. Backup will not be created"
  exit 1
fi

if test -z "${POD_PREFIX}";
then
  alert "Backup job pod name is not defined. Backup will not be created"
  exit 1
fi

if test -z "${TYPEOFBACKUP}";
then
  TYPEOFBACKUP="${TYPEOFBACKUP_DEFAULT}"
fi

if test "${DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME}" == "yes";
then
  REPOSITORY="${BORG_SERVER}:${NAMEOFBACKUP}"
else
  REPOSITORY="${BORG_SERVER}:$(hostname)-${NAMEOFBACKUP}"
fi

EXCLUDE_PARAM=""
if test "${EXCLUDE_PATTERN}" != '';
then
  EXCLUDE_PARAM="--exclude ${EXCLUDE_PATTERN}"
fi

if test "${CONTEXT}" != '';
then
  CONTEXT="--context=${CONTEXT}"
fi

POD=$(${KUBECTL} ${CONTEXT} get pods -n ${NAMESPACE} | grep "${POD_PREFIX}" | awk '{print $1}' | head -n 1)
if test -z "${POD}";
then
  alert "Backup job can't find pod named like ${POD_PREFIX}*. Backup will not be created"
  exit 1
fi

if test -z "${DIRS_QUOTED}";
then
  DIRS=`${KUBECTL} ${CONTEXT} get pod -n ${NAMESPACE} ${POD} -o json | jq '.spec.containers[].volumeMounts[].mountPath' | grep -v "secrets/kubernetes.io/serviceaccount" | awk -F\" '{print $2}' | tr "\n" " "`
else
  DIRS="${DIRS_QUOTED}"
fi

if test "${POD_CONTAINER}" != '';
then
  POD_CONTAINER="-c ${POD_CONTAINER}"
fi

TEMPLOG="$( mktemp )"
TEMPLOGPRUNE="$( mktemp )"

printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
borg init -e none "${REPOSITORY}"

COMMAND_LINE=\
"${KUBECTL} ${CONTEXT} exec -n ${NAMESPACE} ${POD} ${POD_CONTAINER} -- tar cf - ${EXCLUDE_PARAM} ${DIRS} 2>>$TEMPLOG"
BORG_COMMAND_LINE=\
"borg create --show-rc --stats \
'${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' -"

printf "%s\n" "Create backup archive:"
printf "%s\n" "${COMMAND_LINE} | ${BORG_COMMAND_LINE}"
bash -c "${COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"

CREATE_EXIT=( "${PIPESTATUS[@]}" )

# Print log to stdout for manual run and logger
cat "${TEMPLOG}"

if test "${CREATE_EXIT[0]}" -ne 0;
then
  alert "${KUBECTL} exec failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  unlink "${TEMPLOGPRUNE}"
  exit 1
fi

if test "${CREATE_EXIT[1]}" -ne 0;
then
  alert "borg create failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  unlink "${TEMPLOGPRUNE}"
  exit 1
fi

unlink "${TEMPLOG}"

# --keep-hourly=1 - if backup binlog - keep backups for every hour
# Don't use other --keep-* if you create binlog backup!
# Example: Binlogs per hour will be PRUNED if user --keep-daily=1

PRUNE_COMMAND_LINE=\
"borg prune --show-rc --list '${REPOSITORY}' \
${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}"

printf "%s\n" "Prune old backup archives:"
printf "%s\n" "${PRUNE_COMMAND_LINE}"
printf "%s\n" "${PRUNE_COMMAND_LINE}" | bash &> "${TEMPLOGPRUNE}"

PRUNE_EXIT="${?}"

# Print log to stdout for manual run and logger
cat "${TEMPLOGPRUNE}"

if test "${PRUNE_EXIT}" -ne 0;
then
  alert "borg prune failed" "$( tail -n 20 < "${TEMPLOGPRUNE}" )"
  unlink "${TEMPLOGPRUNE}"
  exit 2
fi

unlink "${TEMPLOGPRUNE}"

exit 0
