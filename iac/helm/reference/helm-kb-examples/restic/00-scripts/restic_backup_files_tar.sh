#!/usr/bin/env bash

# Этот скрипт - запасной способ бэкапа файлов. Файлы сперва помещаются в tar-архив.
# Это необходимо для хранения в одном бэкапе restic переменного списка файлов, чтобы на это не срабатывал мониторинг.
# Актуально, например, для binlog-файлов, хранящихся в общем каталоге mysql.

# Принцип работы:
#   - создание бэкапа файлов и/или каталогов в restic-репозитории с помощью
#     'restic backup'
#   - удаление старых бэкапов в restic-репозитории с помощью 'restic forget --prune'

# Поддерживаемые опции:
# -q|--add-quoted                - путь к файлу или каталогу который необходимо
#                                  зарезервировать. Опция может быть указана несколько раз, в
#                                  резервную копию попадут все указанные файлы и/или каталоги.
#                                  Указанные пути будут помещены в одинарные кавычки - будут
#                                  корректно обработаны пути с пробелами, но не будут работать
#                                  wildcard-подстановки. Необязательный аргумент, пути к
#                                  файлам и/или каталогам должны быть указаны или с помощью
#                                  этой опции, или с помощью позиционного аргумента ${2},
#                                  также они могут быть использованы совместно
# -t|--tar-options               - Опции tar для формировании архива. Необязательный аргумент.
# -k|--prune                     - строка с опциями алгоритма сохранения резервных копий в
#                                  формате программы restic, например '--keep-hourly 72 --keep-within 30d'
#                                  Необязательный аргумент, без указания этой опции будет
#                                  использовано значение ${CUSTOMPRUNE_DEFAULT}

# Позиционные аргументы:
# ${1} - имя задания, тег restic-репозитория. Обязательный аргумент
# ${2} - разделенные запятыми, пути к файлам или каталогам которые необходимо
#        зарезервировать. Можно использовать wildcard-подстановки, пробелы в
#        путях будут обработаны НЕкорректно. Обязательный аргумент, если не
#        использована опция -q|--add-quoted или требуется указать исключения
#        из резервного копирования с помощью позиционного аргумента ${3}

# Примеры использования в schedule:
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_files.sh 'SYSTEM /etc,/var/spool/cron,/etc/backup-agent/config.d'
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_files.sh 'DATA /var'
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_files.sh 'DATA /var --tar-options "--exclude=temp-* --exclude=lost+found"'
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_files.sh 'DATA /var --tar-options "--exclude=temp-* --exclude=lost+found --warning=no-file-changed" --prune "--keep-hourly 3 --keep-within 30d"'
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_files.sh 'LOGS /var/log/auth.log*,/var/log/wtmp* --add-quoted "/var/log/apt" --add-quoted "/var/log/cups"'
################################################################################

CUSTOMPRUNE_DEFAULT='--keep-hourly 1 --keep-within 65d'

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP}"
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  printf "%s\n" "ERROR: ${MESSAGE}"
  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

################################################################################

DIRS_QUOTED=""
TAR_OPTIONS=""
CUSTOMPRUNE=""

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options q:t:k: --longoptions ,add-quoted:,tar-options:,prune:,prefix: -- "${@}" 2>/dev/null )"
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
    -t|--tar-options)               TAR_OPTIONS="${2}";               shift 2;;
    -k|--prune)                     CUSTOMPRUNE="${2}";               shift 2;;
    *) break ;;
  esac
done

NAMEOFBACKUP="${2}"
DIRS="${3}"

if test -z "${NAMEOFBACKUP}";
then
  alert "Backup job name is not defined. Backup will not be created"
  exit 1
fi

if test -z "${DIRS}" -a -z "${DIRS_QUOTED}";
then
  alert "Files or directories for backup is not defined. Backup will not be created"
  exit 1
fi

if test "${DO_NOT_USE_HOSTNAME_IN_RESTIC_REPO_NAME}" == "yes";
then
  RESTIC_HOSTNAME="${NAMEOFBACKUP}"
else
  RESTIC_HOSTNAME="$( hostname )"
fi

TEMPLOG="$( mktemp )"
TEMPLOGPRUNE="$( mktemp )"

DIRS_EVOLVED="$( printf "%s" "${DIRS}" | tr ',' ' ' )"

restic init || echo "skip initialization."

COMMAND_LINE=\
"tar ${TAR_OPTIONS} -cf - ${DIRS} 2>>$TEMPLOG"

RESTIC_COMMAND_LINE=\
"restic backup --verbose \
--tag ${NAMEOFBACKUP} \
--stdin --stdin-filename ${NAMEOFBACKUP}.tar"

printf "%s\n" "Create backup archive:"
printf "%s\n" "${COMMAND_LINE} | ${RESTIC_COMMAND_LINE}"
bash -c "${COMMAND_LINE}" | bash -c "${RESTIC_COMMAND_LINE}"

#CREATE_COMMAND_LINE=\
#"restic backup --verbose \
#--tag ${NAMEOFBACKUP} \
#${DIRS_EVOLVED} ${DIRS_QUOTED} \
#--exclude '${DIRS_EXCLUDE_EVOLVED}' \
#--hostname '${RESTIC_HOSTNAME}'"

#printf "%s\n" "Create backup archive:"
#printf "%s\n" "${CREATE_COMMAND_LINE}"
#printf "%s\n" "${CREATE_COMMAND_LINE}" | bash &> "${TEMPLOG}"

CREATE_EXIT=( "${PIPESTATUS[@]}" )

# Print log to stdout for manual run and logger
cat "${TEMPLOG}"

if test "${CREATE_EXIT[0]}" -ne 0 -a "${CREATE_EXIT[0]}" -ne 1;
then
  alert "tar exec failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  unlink "${TEMPLOGPRUNE}"
  exit 1
fi

if test "${CREATE_EXIT[1]}" -ne 0;
then
  alert "restic create failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  unlink "${TEMPLOGPRUNE}"
  exit 1
fi

unlink "${TEMPLOG}"

# --keep-hourly=1 - if backup binlog - keep backups for every hour
# Don't use other --keep-* if you create binlog backup!
# Example: Binlogs per hour will be PRUNED if user --keep-daily=1

PRUNE_COMMAND_LINE=\
"restic forget --prune --tag '${NAMEOFBACKUP}' \
${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}"

printf "%s\n" "Prune old backup archives:"
printf "%s\n" "${PRUNE_COMMAND_LINE}"
printf "%s\n" "${PRUNE_COMMAND_LINE}" | bash &> "${TEMPLOGPRUNE}"

PRUNE_EXIT="${?}"

# Print log to stdout for manual run and logger
cat "${TEMPLOGPRUNE}"

if test "${PRUNE_EXIT}" -ne 0;
then
  alert "restic prune failed" "$( tail -n 20 < "${TEMPLOGPRUNE}" )"
  unlink "${TEMPLOGPRUNE}"
  exit 2
fi

unlink "${TEMPLOGPRUNE}"

exit 0
