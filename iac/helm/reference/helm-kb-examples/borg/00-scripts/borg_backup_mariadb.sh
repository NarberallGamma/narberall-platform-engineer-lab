#!/usr/bin/env bash

# Этот скрипт - основной способ бэкапа MariaDB 10.1.23/10.2.7 и более свежих версий

# Его можно применять если (должны выполняться все условия):
#   1. на узле с сервером MariaDB доступна утилита mariabackup (форк xtrabackup/innobackupex)
#   2. в случае создания бэкапа со slave-сервера, на нем НЕ производятся
#      DDL-модификации (изменения структур баз данных), иначе бэкап будет неконсистентным

# Принцип работы:
#   - вызов mariabackup с передачей дампа в stdout
#   - резервное копирование дампа с помощью borg с получением дампа из stdin

# Поддерживаемые опции:
# -c|--defaults-file         -    путь к файлу с параметрами подключения к
#                                 MariaDB-серверу и работы с ним, такими как host,
#                                 user, password, socket и т.п. (опция mariabackup
#                                 --defaults-file). Без указания этой опции
#                                 будет использован файл указанный в переменной
#                                 ${DEFAULTS_FILE_DEFAULT}
# -n|--ulimit-n                 - устанавливает максимальное количество
#                                 одновременно открытых файловых дескрипторов
#                                 для процесса. Без указания этой опции будет
#                                 использовано значение указанное в переменной
#                                 ${ULIMIT_N_DEFAULT}
# -a|--add-innobackupex-option  - дополнительная опция innobackupex которая будет передана
#                                 mariabackup. Если опция innobackupex имеет
#                                 значение, то его необходимо указать либо через
#                                 знак равенства ( = ) (возможно только для
#                                 длинных опций), либо через пробел, но в
#                                 этом случае опцию innobackupex вместе с ее
#                                 значением необходимо поместить в двойные или
#                                 одинарные кавычки. Например:
#                                   - --add-innobackupex-option --databases=db1
#                                   - --add-innobackupex-option '--databases db1'
#                                   - --add-innobackupex-option "---databases db1"
#                                 Опция innobackupex может быть указана несколько раз,
#                                 mariabackup будут переданы все указанные опции
#                                 Скрипт всегда добавляет опцию --stream=xbstream
# -k|--prune                    - строка с опциями алгоритма сохранения резервных
#                                 копий в формате программы Borg, например
#                                 '--keep-hourly 72 --keep-within=30d'
#                                 Необязательный аргумент, без указания этой опции
#                                 будет использовано значение ${CUSTOMPRUNE_DEFAULT}

# Позиционные аргументы:
# ${1} - имя задания, суффикс имени Borg-репозитория, без указания будет
#        использовано имя заданное в ${NAMEOFBACKUP_DEFAULT}

# Владельцем файла указанного опцией --defaults-file должен быть 'root:root' и
# для него должны быть установлены права '0400'

# Установка зависимостей, пример:
# - mariabackup:
#   - Debian/Ubuntu - sudo apt-get install mariadb-client-10.1

# Пример использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_mariadb.sh
# borg_run_on.sh 10.0.0.1 borg_backup_mariadb.sh 'MARIADB'
# borg_run_on.sh 10.0.0.1 borg_backup_mariadb.sh 'MARIADB --defaults-file "/etc/mysql/debian.cnf"'
# borg_run_on.sh 10.0.0.1 borg_backup_mariadb.sh 'MARIADB --defaults-file "/etc/mysql/debian.cnf" --ulimit-n 300000'
# borg_run_on.sh 10.0.0.1 borg_backup_mariadb.sh 'MARIADB --defaults-file "/etc/mysql/debian.cnf" --ulimit-n 300000 --add-innobackupex-option "--databases \"db1 db2\""'
# borg_run_on.sh 10.0.0.1 borg_backup_mariadb.sh 'MARIADB --defaults-file "/etc/mysql/debian.cnf" --ulimit-n 300000 --add-innobackupex-option "--databases \"db1 db2\"" --prune "--keep-hourly 3 --keep-within=30d"'

################################################################################

source vars

NAMEOFBACKUP_DEFAULT='MARIADB'
TYPEOFBACKUP='mariadb'
DEFAULTS_FILE_DEFAULT='/etc/mysql/debian.cnf'
ULIMIT_N_DEFAULT="200000"
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=14d --keep-weekly=4 --keep-monthly=3'

export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no"

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

trim_trailing_single_quotes()
{
  printf "%s\n" "${1}" | sed --quiet "s/^'*//;s/'$//;p"
}

################################################################################

NAMEOFBACKUP=""
DEFAULTS_FILE=""
ULIMIT_N=""
ADDITIONAL_OPTIONS=""
CUSTOMPRUNE=""

REPOSITORY=""
EFFECTIVE_OPTIONS=""

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options c:n:a:k: --longoptions ,defaults-file:,ulimit-n:,add-innobackupex-option:,prune: -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -c|--defaults-file)           DEFAULTS_FILE="${2}";  shift 2;;
    -n|--ulimit-n)                ULIMIT_N="${2}";       shift 2;;
    -a|--add-innobackupex-option)
                                  if test -z "${ADDITIONAL_OPTIONS}";
                                  then
                                    ADDITIONAL_OPTIONS="'${2}'"
                                  else
                                    ADDITIONAL_OPTIONS="${ADDITIONAL_OPTIONS}"$'\n'"'${2}'"
                                  fi

                                  shift 2;;
    -k|--prune)                   CUSTOMPRUNE="${2}";    shift 2;;
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

if test -z "${ULIMIT_N}";
then
  printf "%s\n" "WARNING: ulimit -n value is not defined, used default value '${ULIMIT_N_DEFAULT}'"
  ULIMIT_N="${ULIMIT_N_DEFAULT}"
fi

REPOSITORY="${BORG_SERVER}:$(hostname)-${NAMEOFBACKUP}"

for option in ${ADDITIONAL_OPTIONS};
do
  if test "${option}" != "''";
  then
    EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
  fi
done

if test -z "${EFFECTIVE_OPTIONS}";
then
  EFFECTIVE_OPTIONS="--innobackupex ${EFFECTIVE_OPTIONS}"
fi

printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
borg init -e none "${REPOSITORY}"

ulimit -n "${ULIMIT_N_DEFAULT}"
if test "${?}" -ne 0;
then
  printf "%s\n" "WARNING: an error occurred while setting ulimit -n '${ULIMIT_N_DEFAULT}'"
fi

MARIABACKUP_COMMAND_LINE=\
"mariabackup --defaults-file='${DEFAULTS_FILE}' --backup ${EFFECTIVE_OPTIONS} --stream=xbstream"

BORG_COMMAND_LINE=\
"borg create --show-rc --stats \
'${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' -"

printf "%s\n" "Create backup archive:"
printf "%s\n" "${MARIABACKUP_COMMAND_LINE} | ${BORG_COMMAND_LINE}"
bash -c "${MARIABACKUP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"

CREATE_EXIT=( "${PIPESTATUS[@]}" )

if test "${CREATE_EXIT[0]}" -ne 0;
then
  alert "mariabackup failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped"
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
