#!/usr/bin/env bash

# Этот скрипт - основной способ бэкапа файлов

# Принцип работы:
#   - создание бэкапа файлов и/или каталогов в borg-репозитории с помощью 
#     'borg create'
#   - удаление старых бэкапов в borg-репозитории с помощью 'borg prune'

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
# -k|--prune                     - строка с опциями алгоритма сохранения резервных копий в 
#                                  формате программы Borg, например '--keep-hourly 72 --keep-within=30d'
#                                  Необязательный аргумент, без указания этой опции будет 
#                                  использовано значение ${CUSTOMPRUNE_DEFAULT}
#    --prefix                    - строка, помещаемая перед именем архива через знак '-', 
#                                  например 'PG-', 'files-'. Необязательный аргумент, без указания 
#                                  этой опции будет использовано значение ${TYPEOFBACKUP_DEFAULT}
#    --dont-ignore-missing-files - по умолчанию скрипт не считает ошибками внезапное 
#                                  исчезновение или потерю доступа к целевым файлам 
#                                  или каталогам (и файлам и каталогам в этих 
#                                  каталогах) т.е. игнорирует ошибки вида 
#                                  '[Errno 2] No such file or directory' и '[Errno 13] Permission denied'.
#                                  Эта опция позволяет отключить игнорирование 
#                                  таких ошибок. При ее использовании скрипт 
#                                  возвращает ненулевое значение и отправляет 
#                                  алерт как и при возникновении других, более серьезных ошибок

# Позиционные аргументы:
# ${1} - имя задания, суффикс имени Borg-репозитория. Обязательный аргумент
# ${2} - разделенные запятыми, пути к файлам или каталогам которые необходимо 
#        зарезервировать. Можно использовать wildcard-подстановки, пробелы в 
#        путях будут обработаны НЕкорректно. Обязательный аргумент, если не 
#        использована опция -q|--add-quoted или требуется указать исключения 
#        из резервного копирования с помощью позиционного аргумента ${3}
# ${3} - исключения из резервного копирования в формате регулярного выражения. 
#        Несколько регулярных выражений могут быть указаны через запятую.
#        Необязательный аргумент

# Примеры использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_files.sh 'SYSTEM /etc,/var/spool/cron,/etc/backup-agent/config.d ^\/etc\/\.git$'
# borg_run_on.sh 10.0.0.1 borg_backup_files.sh 'DATA /var ^\/var\/.*\/lock$'
# borg_run_on.sh 10.0.0.1 borg_backup_files.sh 'DATA /var ^\/var\/.*\/lock$,^\/var\/log/auth.log.*$'
# borg_run_on.sh 10.0.0.1 borg_backup_files.sh 'DATA /var ^\/var\/.*\/lock$,^\/var\/log/auth.log.*$ --prune "--keep-hourly 3 --keep-within=30d"'
# borg_run_on.sh 10.0.0.1 borg_backup_files.sh 'LOGS /var/log/auth.log*,/var/log/wtmp* --add-quoted "/var/log/apt" --add-quoted "/var/log/cups"'

################################################################################

source vars

TYPEOFBACKUP_DEFAULT='files'
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=65d'

export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no"

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
CUSTOMPRUNE=""
TYPEOFBACKUP=""
DONT_IGNORE_MISSING_FILES=""

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options q:k: --longoptions ,add-quoted:,prune:,prefix:,dont-ignore-missing-files -- "${@}" 2>/dev/null )"
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
                                    
    -k|--prune)                     CUSTOMPRUNE="${2}";               shift 2;;
       --prefix)                    TYPEOFBACKUP="${2}";              shift 2;;
       --dont-ignore-missing-files) DONT_IGNORE_MISSING_FILES="yes";  shift 1;;
    *) break ;;
  esac
done

NAMEOFBACKUP="${2}"
DIRS="${3}"
DIRS_EXCLUDE="${4:-^$}"

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

if test -z "${TYPEOFBACKUP}";
then
  TYPEOFBACKUP="${TYPEOFBACKUP_DEFAULT}"
fi

REPOSITORY="${BORG_SERVER}:$(hostname)-${NAMEOFBACKUP}"

TEMPLOG="$( mktemp )"
TEMPLOGPRUNE="$( mktemp )"

if test "${NAMEOFBACKUP}" == "SYSTEM";
then
  00-scripts/create_package_list.sh
  if test "${?}" -ne 0;
  then
    alert "Cannot get list of system packages, SYSTEM backup is not complete"
  else
    DIRS="${DIRS},/tmp/packages"
  fi
fi

DIRS_EVOLVED="$( printf "%s" "${DIRS}" | tr ',' ' ' )"
DIRS_EXCLUDE_EVOLVED="$( printf "%s" "${DIRS_EXCLUDE}" | tr ',' '\|')"

printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
borg init -e none "${REPOSITORY}"

CREATE_COMMAND_LINE=\
"borg create --show-rc --stats \
'${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' \
${DIRS_EVOLVED} ${DIRS_QUOTED} \
--exclude 're:${DIRS_EXCLUDE_EVOLVED}'"

printf "%s\n" "Create backup archive:"
printf "%s\n" "${CREATE_COMMAND_LINE}"
printf "%s\n" "${CREATE_COMMAND_LINE}" | bash &> "${TEMPLOG}"

CREATE_EXIT="${?}"

# Print log to stdout for manual run and logger
cat "${TEMPLOG}"

if test "${DONT_IGNORE_MISSING_FILES}" != "yes" -a "${CREATE_EXIT}" -ne 0 -a "${CREATE_EXIT}" -ne 1;
then
  alert "borg create failed. Pruning of old archives skipped" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  unlink "${TEMPLOGPRUNE}"
  exit 2
fi

if test "${DONT_IGNORE_MISSING_FILES}" == "yes" -a "${CREATE_EXIT}" -ne 0;
then
  alert "borg create failed. Pruning of old archives skipped" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  unlink "${TEMPLOGPRUNE}"
  exit 2
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
