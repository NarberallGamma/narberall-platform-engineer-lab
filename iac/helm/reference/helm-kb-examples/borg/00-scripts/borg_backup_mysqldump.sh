#!/usr/bin/env bash

# Этот скрипт - запасной способ бэкапа MySQL

# Его можно применять если (должны выполняться все условия):
#   1. если есть хотя бы одна таблица для работы с которой НЕ используется движок InnoDB
#   2. допустима блокировка баз MySQL на время бэкапа
#   3. размер баз MySQL и другие условия позволяют выполнить бэкап за время,
#      отведенное на эту операцию резервного копирования

# Принцип работы:
#   - вызов mysqldump с передачей дампа в stdout
#   - резервное копирование дампа с помощью borg с получением дампа из stdin

# Поддерживаемые опции:
# -c|--defaults-file         - путь к файлу с параметрами подключения к
#                              MySQL-серверу и работы с ним, такими как host,
#                              user, password, socket и т.п. (опция mysqldump
#                              --defaults-file). Без указания этой опции
#                              будет использован файл указанный в пременной
#                              ${DEFAULTS_FILE_DEFAULT}
# -d|--db                    - имя базы данных которую необходимо бэкапить,
#                              опция может быть указана несколько раз, в
#                              резервную копию попадут все указанные базы.
#                              Без указания этой опции в резервную копию
#                              попадут все базы, включая служебные ( mysql,
#                              information_schema, performance_schema )
# -a|--add-mysqldump-option  - дополнительная опция которая будет передана
#                              mysqldump. Если опция mysqldump имеет значение,
#                              то его необходимо указать либо через знак
#                              равенства ( = ) (возможно только для длинных
#                              опций), либо через пробел, но в этом случае опцию
#                              mysqldump вместе с ее значением необходимо
#                              поместить в двойные или одинарные кавычки.
#                              Например:
#                               - --add-mysqldump-option --ignore-table=db1.table1
#                               - --add-mysqldump-option '--ignore-table db1.table1'
#                               - --add-mysqldump-option "--ignore-table db1.table1"
#                              Опция может быть указана несколько раз,
#                              mysqldump будут переданы все указанные опции
#                              Скрипт всегда пытается добавить опции
#                              перечисленные в ${DESIRED_OPTIONS}
# -k|--prune                 - строка с опциями алгоритма сохранения резервных
#                              копий в формате программы Borg, например
#                              '--keep-hourly 72 --keep-within=30d'
#                              Необязательный аргумент, без указания этой опции
#                              будет использовано значение ${CUSTOMPRUNE_DEFAULT}
#    --skip-hostname-prefix  - позволяет исключить из имени Borg-репозитория
#                              префикс '$(hostname)-'. Необязательный аргумент

# Позиционные аргументы:
# ${1} - имя задания, суффикс имени Borg-репозитория, без указания будет
#        использовано имя заданное в ${NAMEOFBACKUP_DEFAULT}

# Владельцем файла указанного опцией --defaults-file должен быть 'root:root' и
# для него должны быть установлены права '0400'

# Установка зависимостей:
# - mysqldump:
#   - Debian/Ubuntu - sudo apt-get install mysql-client

# Пример использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh 'MYSQLDUMP'
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf"'
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf" --db db1 --db db2'
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf" --db db1 --db db2 --add-mysqldump-option "--ignore-table db1.table1"'
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf" --db db1 --db db2 --add-mysqldump-option "--ignore-table db1.table1" --add-mysqldump-option --hex-blob'
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf" --db db1 --db db2 --add-mysqldump-option "--ignore-table db1.table1" --add-mysqldump-option --hex-blob --prune "--keep-hourly 3 --keep-within=30d"'

################################################################################

source vars

NAMEOFBACKUP_DEFAULT='MYSQLDUMP'
TYPEOFBACKUP='mysqldump'
DEFAULTS_FILE_DEFAULT='/etc/mysql/debian.cnf'
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=14d --keep-weekly=4 --keep-monthly=3'

export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no"

DESIRED_OPTIONS="
'--single-transaction'
'--routines'
"

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP:-${NAMEOFBACKUP_DEFAULT}}"
  CLUSTER=${CLUSTER:-unknown}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  printf "%s\n" "ERROR: ${MESSAGE}"
  backup_notify --trigger backup --label cluster="${CLUSTER}" --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

get_long_option_key()
{
  printf "%s\n" "${1}" | sed --quiet "s/$/=/;s/^[ \t]*--\([^= -][^= ][^= ]*\)[= ].*/\1/;p"
}

trim_trailing_single_quotes()
{
  printf "%s\n" "${1}" | sed --quiet "s/^'*//;s/'$//;p"
}

################################################################################

NAMEOFBACKUP=""
DEFAULTS_FILE=""
DBS=""
ADDITIONAL_OPTIONS=""
CUSTOMPRUNE=""

REPOSITORY=""
DBS_LINE=""
DATABASES_OPTION=""
EFFECTIVE_OPTIONS=""
MYSQLDUMP_HELP=""

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options c:d:a:k: --longoptions ,defaults-file:,db:,add-mysqldump-option:,prune:,skip-hostname-prefix -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -c|--defaults-file)         DEFAULTS_FILE="${2}";  shift 2;;
    -d|--db)
                                if test -z "${DBS}";
                                then
                                  DBS="'${2}'"
                                else
                                  DBS="${DBS}"$'\n'"'${2}'"
                                fi

                                shift 2;;
    -a|--add-mysqldump-option)
                                if test -z "${ADDITIONAL_OPTIONS}";
                                then
                                  ADDITIONAL_OPTIONS="'${2}'"
                                else
                                  ADDITIONAL_OPTIONS="${ADDITIONAL_OPTIONS}"$'\n'"'${2}'"
                                fi

                                shift 2;;

    -k|--prune)                 CUSTOMPRUNE="${2}";   shift 2;;
       --skip-hostname-prefix)  DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME="yes";  shift 1;;
    *) break ;;
  esac
done

IFS=$'\n'

NAMEOFBACKUP="${2}"

if test -z "${NAMEOFBACKUP}";
then
  printf "%s\n" "WARNING: job name is not defined, used default value '${NAMEOFBACKUP_DEFAULT}'"
  NAMEOFBACKUP="${NAMEOFBACKUP_DEFAULT}"
fi

if test -z "${DEFAULTS_FILE}";
then
  printf "%s\n" "WARNING: defaults file is not defined, used default value '${DEFAULTS_FILE_DEFAULT}'"
  DEFAULTS_FILE="${DEFAULTS_FILE_DEFAULT}"
fi

if test "${DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME}" == "yes";
then
  REPOSITORY="${BORG_SERVER}:${NAMEOFBACKUP}"
else
  REPOSITORY="${BORG_SERVER}:$(hostname)-${NAMEOFBACKUP}"
fi

for db in ${DBS};
do
  if test "${db}" != "''";
  then
    DBS_LINE="${DBS_LINE} ${db}"
  fi
done

if test -z "${DBS_LINE}";
then
  DATABASES_OPTION="--all-databases"
else
  DATABASES_OPTION="--databases"
fi

MYSQLDUMP_HELP="$( mysqldump --help | sed --quiet "s/$/ /;p" )"

for option in ${DESIRED_OPTIONS};
do
  if test "${option}" != "''";
  then
    option_key=""
    option_key="$( get_long_option_key "$( trim_trailing_single_quotes "${option}" )" )"
    if test -n "$( printf "%s" "${MYSQLDUMP_HELP}" | grep "\-\-${option_key} " )" \
    -o -n "$( printf "%s" "${MYSQLDUMP_HELP}" | grep "\-\-${option_key}=" )" \
    -o -n "$( printf "%s" "${MYSQLDUMP_HELP}" | grep "\-\-${option_key}\[=.*\]" )";
    then
      EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
    else
      printf "%s\n" "WARNING: option --${option_key} not supported and skipped"
    fi
  fi
done

for option in ${ADDITIONAL_OPTIONS};
do
  if test "${option}" != "''";
  then
    EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
  fi
done

printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
borg init -e none "${REPOSITORY}"

MYSQLDUMP_COMMAND_LINE=\
"mysqldump --defaults-file='${DEFAULTS_FILE}' ${DATABASES_OPTION} ${EFFECTIVE_OPTIONS} ${DBS_LINE}"

BORG_COMMAND_LINE=\
"borg create --show-rc --stats \
'${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' -"

printf "%s\n" "Create backup archive:"
printf "%s\n" "${MYSQLDUMP_COMMAND_LINE} | ${BORG_COMMAND_LINE}"
bash -c "${MYSQLDUMP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"

CREATE_EXIT=( "${PIPESTATUS[@]}" )

if test "${CREATE_EXIT[0]}" -ne 0;
then
  alert "mysqldump failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped"
  exit 1
fi

if test "${CREATE_EXIT[1]}" -ne 0;
then
  alert "borg create failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped"
  exit 1
fi

PRUNE_COMMAND_LINE=\
"borg prune --show-rc --list '${REPOSITORY}' \
${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}"

printf "%s\n" "Prune old backup archives:"
printf "%s\n" "${PRUNE_COMMAND_LINE}"
printf "%s\n" "${PRUNE_COMMAND_LINE}" | bash

PRUNE_EXIT="${?}"

if test "${PRUNE_EXIT}" -ne 0;
then
  alert "borg prune failed, exit code ${PRUNE_EXIT}"
  exit 1
fi

exit 0
