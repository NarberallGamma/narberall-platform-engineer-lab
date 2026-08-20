#!/usr/bin/env bash

# Этот скрипт - запасной способ бэкапа PostgreSQL

# Принцип работы:
#   - вызов pg_basebackup с помещением на лету файлов данных PostgreSQL в tar-архив и сохранением его во временном каталоге ${TMP_DIR}
#   - резервное копирование временного каталога с помощью borg

# Его можно применять если (должны выполняться все условия):
#   1. размер дампа баз PostgreSQL меньше доступного места в файловой системе
#      в которой располагается каталог ${TMP_DIR}
#   2. основной скрипт бэкапа borg_backup_postgres_stdout.sh невозможно
#      применять в данных условиях, например:
#     2.1 скорость передачи данных по сети от узла с сервером PostgreSQL до
#         хранилища borg-бэкапов низка настолько, что вызывает отключение
#         pg_basebackup от PostgreSQL-сервера по таймауту

# Поддерживаемые опции:
# -h|--host                      - адрес подключения к PostgreSQL. Необязательный аргумент
# -r|--port                      - порт подключения к PostgreSQL. Необязательный аргумент
# -u|--user                      - имя пользователя, используемого для подключения
#                                  к PostgreSQL или запуска pg_basebackup. Необязательный
#                                  аргумент, без указания этой опции будет использовано
#                                  значение ${USER_DEFAULT}
# -p|--password                  - путь к файлу с паролем, используемым для
#                                  подключения к PostgreSQL, или имя переменной
#                                  окружения, содержащей этот пароль. Необязательный аргумент
# -a|--add-pg_basebackup-option  - дополнительная опция которая будет передана
#                                  pg_basebackup. Если опция pg_basebackup имеет
#                                  значение, то его необходимо указать либо через
#                                  знак равенства ( = ) (возможно только для
#                                  длинных опций), либо через пробел, но в
#                                  этом случае опцию pg_basebackup вместе с ее
#                                  значением необходимо поместить в двойные или
#                                  одинарные кавычки. Например:
#                                   - --add-pg_basebackup-option --max-rate=1024
#                                   - --add-pg_basebackup-option '--max-rate 1024'
#                                   - --add-pg_basebackup-option "--max-rate 1024"
#                                  Опция может быть указана несколько раз,
#                                  pg_basebackup будут переданы все указанные опции.
#                                  Необязательный аргумент
# -k|--prune                     - строка с опциями алгоритма сохранения резервных копий в
#                                  формате программы Borg, например '--keep-hourly 72 --keep-within=30d'
#                                  Необязательный аргумент, без указания этой опции будет
#                                  использовано значение ${CUSTOMPRUNE_DEFAULT}
#    --do-su-under-user          - запустить pg_basebackup под пользователем, указанным
#                                  опцией -u|--user или пользователем по умолчанию. Имеет
#                                  смысл использовать в том случае, если по каким-либо
#                                  причинам требуется вместо метода аутентификации 'trust'
#                                  в pg_hba.conf использовать метод аутентификации 'peer'
#    --tmp-dir                   - путь к временному каталогу в котором сохраняются
#                                  данные PostgreSQL. Необязательный аргумент, без
#                                  указания этой опции будет использовано значение ${TMP_DIR_DEFAULT}

# Позиционные аргументы:
# ${1} - имя задания, суффикс имени Borg-репозитория, без указания будет
#        использовано имя заданное в ${NAMEOFBACKUP_DEFAULT}

# Примеры использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh 'PG'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh 'PG --user postgres'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh 'PG --user postgres --do-su-under-user'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh 'PG --user postgres --do-su-under-user -a "--max-rate 1024" -a --progress'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh 'PG --user postgres --do-su-under-user -a "--max-rate 1024" -a --progress --prune "--keep-hourly 3 --keep-within=30d"'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh 'PG --host 127.0.0.1 --user pg_super --password "/etc/backup/pg-pass"'

# Запрещается указывать в качестве значения опции [-p, --password]
# непосредственно пароль. В качестве ее значения необходимо указать:
#   - путь к файлу с паролем. Владельцем этого файл должен быть 'root:root' и
#     для него должны быть установлены права '0400'
#   - имя переменной окружения, содержащей этот пароль

# Попытки указать в качестве временного каталога каталоги уровня
# меньше чем 3 т.е. '/', '/etc', '/var' и т.п., а также каталоги перечисленные
# в ${PROTECTED_DIRS} приведут к аварийному завершению скрипта и отсутствию бэкапов

# Для работы этого скрипта необходимо чтобы в PostgreSQL:
#   1. было настроено создание WAL-файлов (файл - postgresql.conf):
#     1.1 значение опции wal_level должно быть >= archive (если ее значение уже
#         >= archive - изменять не нужно)
#     1.2 значение опции wal_keep_segments должно быть > 0 (если ее значение уже
#         > 0 - изменять только в случае проблем и только по согласованию с командой/клиентом)
#         При самостоятельном изменении этой опции необходимо выбрать ее значение
#         таким, чтобы оно было больше на 20-40% количества WAL-файлов, создающихся
#         за время бэкапа (при условии наличия в файловой системе достаточного
#         количества доступного места):
#        1.2.1 определить время выполения бэкапа
#        1.2.2 определить количество генерирующихся за это время WAL-файлов
#        1.2.3 установить wal_keep_segments равной (1.2 ~ 1.4) x (количество генерирующихся за время выполения бэкапа WAL-файлов)
#        1.2.4 убедится что в файловой системе, в которой хранятся WAL-файлы,
#              доступно места больше чем (wal_keep_segments x wal_segment_size)
#     1.3 значение опции max_wal_senders должно быть > 0 (рекомендуемое значение - 5,
#         если ее значение уже > 0 - изменять только в случае проблем и только по
#         согласованию с командой/клиентом)
#     1.4 для применения этих параметров требуется перезупуск сервиса PostgreSQL
#   2. была разрешена репликация для системного пользователя postgres с адреса
#      127.0.0.1/32 или с Unix-сокета (файл - pg_hba.conf):
#     2.1 должна присутствовать незакомментированная строка
#         host    replication     postgres        127.0.0.1/32            trust
#         или строка
#         local   replication     postgres                                trust
#     2.2 для применения этих параметров необходимо послать PostgreSQL сигнал о
#         необходимости перечитать конфигурационный файл с помощью комманды
#         pg_ctlcluster <version> <cluster> reload,
#         где <version>, <cluster> - версия и имя PostgreSQL-кластера соответственно,
#         которые можно узнать коммандой pg_lsclusters
#   3. версия PostgreSQL была больше либо равна 9.1

################################################################################

source vars

NAMEOFBACKUP_DEFAULT='PG'
TYPEOFBACKUP='PG'
USER_DEFAULT="postgres"
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=14d --keep-weekly=4 --keep-monthly=3'
TMP_DIR_DEFAULT="/tmp/pg_basebackup"

export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no"

declare -A PG_BASEBACKUP_COMMON_OPTIONS
PG_BASEBACKUP_COMMON_OPTIONS['9']="--checkpoint=fast --format=tar --label=backup --xlog"
PG_BASEBACKUP_COMMON_OPTIONS['10']="--checkpoint=fast --format=tar --label=backup --wal-method=fetch"
PG_BASEBACKUP_COMMON_OPTIONS['11']="--checkpoint=fast --format=tar --label=backup --wal-method=fetch"
PG_BASEBACKUP_COMMON_OPTIONS['14']="--checkpoint=fast --format=tar --label=backup --wal-method=fetch"

PROTECTED_DIRS='
/
/etc
/root
/home
/var
'

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

trim_trailing_spaces()
{
  printf "%s" "${1}" | sed --quiet "s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;p"
}

trim_trailing_single_quotes()
{
  printf "%s" "${1}" | sed --quiet "s/^'*//;s/'*$//;p"
}

get_env_var_value()
{
  if test -n "${1}";
  then
    printenv | grep --fixed-regexp "${1}=" | sed --quiet "s/[^=]*=//;s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;s/\r//g;p"
  fi
}

extract_version_string()
{
  printf "%s" "${1}" | grep --only-matching '[0-9][0-9]*\(\.[0-9][0-9]*\)\{1,\}' | head -n 1
}

get_major_version()
{
  printf "%s" "${1}" | sed --quiet "s/^\([0-9][0-9]*\)\..*/\1/;p"
}

# Корректно сравнивает пути VFS
# uncertain - неопределенное состояние, один из аргументов не VFS-путь
# equal     - пути равны
# not_equal - пути не равны
# ${1} - one path
# ${2} - two path
compare_vfs_paths()
{
  local one_path_normalized
  local two_path_normalized
  local one_vfs_dividers_string
  local two_vfs_dividers_string

  if test -z "${1}";
  then
    printf "%s" "uncertain"
    return 1
  fi

  if test -z "${2}";
  then
    printf "%s" "uncertain"
    return 1
  fi

  one_path_normalized="$( printf "%s" "${1}/" | sed --quiet "s/\/\/*/\//g;p;" )"
  two_path_normalized="$( printf "%s" "${2}/" | sed --quiet "s/\/\/*/\//g;p;" )"

  one_vfs_dividers_string="$( printf "%s" "${one_path_normalized}" | sed --quiet "s/\/[^\/]\{1,\}/\//g;p;" )"
  two_vfs_dividers_string="$( printf "%s" "${two_path_normalized}" | sed --quiet "s/\/[^\/]\{1,\}/\//g;p;" )"

  if test "$( printf "%s" "${one_vfs_dividers_string}" | sed --quiet "s/[^\/]//g;p;" )" != "${one_vfs_dividers_string}";
  then
    printf "%s" "uncertain"
    return 1
  fi

  if test "$( printf "%s" "${two_vfs_dividers_string}" | sed --quiet "s/[^\/]//g;p;" )" != "${two_vfs_dividers_string}";
  then
    printf "%s" "uncertain"
    return 1
  fi

  if test "${one_path_normalized}" == "${two_path_normalized}";
  then
    printf "%s" "equal"
  else
    printf "%s" "not_equal"
  fi

  return 0
}

# Определяет уровень (глубину) переданного пути относительно корня VFS
# 0 - не VFS путь
# 1 - '/'
# 2 - '/etc', '/root', '/var' и т.п.
# ${1} - path
get_vfs_path_level()
{
  local path_normalized
  local vfs_dividers_string

  if test -z "${1}";
  then
    printf "%s" "0"
    return 1
  fi

  path_normalized="$( printf "%s" "${1}/" | sed --quiet "s/\/\/*/\//g;p;" )"
  vfs_dividers_string="$( printf "%s" "${path_normalized}" | sed --quiet "s/\/[^\/]\{1,\}/\//g;p;" )"

  if test "$( printf "%s" "${vfs_dividers_string}" | sed --quiet "s/[^\/]//g;p;" )" != "${vfs_dividers_string}";
  then
    printf "%s" "0"
    return 1
  fi

  printf "%s" "${vfs_dividers_string}" | wc -m

  return 0
}

################################################################################
NAMEOFBACKUP=""
HOST=""
PORT=""
USER=""
PASSWORD=""
ADDITIONAL_OPTIONS=""
CUSTOMPRUNE=""
DO_SU_UNDER_USER=""
TMP_DIR=""

PASSWORD_EVOLVED=""
EFFECTIVE_OPTIONS=""
PG_BASEBACKUP_MAJOR_VERSION=""

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options h:r:u:p:a:k: --longoptions ,host:,port:,user:,password:,add-pg_basebackup-option:,prune:,do-su-under-user,tmp-dir: -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -h|--host)                      HOST="${2}";         shift 2;;
    -r|--port)                      PORT="${2}";         shift 2;;
    -u|--user)                      USER="${2}";         shift 2;;
    -p|--password)                  PASSWORD="${2}";     shift 2;;
    -a|--add-pg_basebackup-option)
                                    if test -z "${ADDITIONAL_OPTIONS}";
                                    then
                                      ADDITIONAL_OPTIONS="'${2}'"
                                    else
                                      ADDITIONAL_OPTIONS="${ADDITIONAL_OPTIONS}"$'\n'"'${2}'"
                                    fi

                                    shift 2;;

    -k|--prune)                     CUSTOMPRUNE="${2}";     shift 2;;
       --do-su-under-user)          DO_SU_UNDER_USER="yes"; shift 1;;
       --tmp-dir)                   TMP_DIR="${2}";         shift 2;;
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

if test -n "${HOST}";
then
  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --host='${HOST}'"
fi

if test -n "${PORT}";
then
  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --port='${PORT}'"
fi

if test -z "${USER}";
then
  printf "%s\n" "WARNING: user name is not defined, used default value '${USER_DEFAULT}'"
  USER="${USER_DEFAULT}"
fi

EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --username='${USER}'"

if test -n "${PASSWORD}";
then
  if test -f "${PASSWORD}";
  then
    PASSWORD_EVOLVED="$( head -n 1 "${PASSWORD}" )"
    PASSWORD_EVOLVED="$( trim_trailing_spaces "${PASSWORD_EVOLVED}" )"
  else
    PASSWORD_EVOLVED="$( get_env_var_value "${PASSWORD}" )"
  fi
fi

if test -n "${PASSWORD_EVOLVED}";
then
  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --password"
fi

PG_BASEBACKUP_MAJOR_VERSION="$( get_major_version "$( extract_version_string "$( pg_basebackup --version )" )" )"

if test -z "${PG_BASEBACKUP_MAJOR_VERSION}";
then
  alert "Cannot determine pg_basebackup major version. Backup will not be created"
  exit 1
fi

if test -z "${PG_BASEBACKUP_COMMON_OPTIONS["${PG_BASEBACKUP_MAJOR_VERSION}"]}";
then
  alert "pg_basebackup have unsupported version. Backup will not be created"
  exit 1
fi

EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} ${PG_BASEBACKUP_COMMON_OPTIONS["${PG_BASEBACKUP_MAJOR_VERSION}"]}"

for option in ${ADDITIONAL_OPTIONS};
do
  if test "${option}" != "''";
  then
    EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
  fi
done

if test -z "${TMP_DIR}";
then
  printf "%s\n" "WARNING: temporary directory is not defined, used default value '${TMP_DIR_DEFAULT}'"
  TMP_DIR="${TMP_DIR_DEFAULT}"
fi

for dir in ${PROTECTED_DIRS};
do
if test "$( compare_vfs_paths "${TMP_DIR}" "${dir}" )" == "equal" -o "$( compare_vfs_paths "${TMP_DIR}" "${dir}" )" == "uncertain";
  then
    alert "Directory '${dir}' is protected and cannot be specified as the temporary directory. Backup will not be created"
    exit 1
  fi
done

if test "$( get_vfs_path_level "${TMP_DIR}" )" -le "2";
then
  alert "Temporary directory level cannot be less that 2. Backup will not be created"
  exit 1
fi

if test -d "${TMP_DIR}";
then
  printf "%s\n" "Remove temporary directory '${TMP_DIR}':"
  rm -rf "${TMP_DIR}"
fi

if test ! -d "${TMP_DIR}";
then
  printf "%s\n" "Create temporary directory '${TMP_DIR}':"
  mkdir -p "${TMP_DIR}"
  if test ! -d "${TMP_DIR}";
  then
    alert "Cannot create temporary directory '${TMP_DIR}'. Backup will not be created"
    exit 1
  fi
fi

if test "${DO_SU_UNDER_USER}" == "yes";
then
  printf "%s\n" "Change owner for temporary directory to '${USER}':"
  chown "${USER}" "${TMP_DIR}"
  if test "${?}" -ne 0;
  then
    alert "Cannot change owner for temporary directory '${TMP_DIR}' to '${USER}'. Backup will not be created"
    exit 1
  fi
fi

PG_BASEBACKUP_COMMAND_LINE=\
"pg_basebackup ${EFFECTIVE_OPTIONS} --pgdata='${TMP_DIR}'"

printf "%s\n" "Create backup in temporary directory:"

if test -z "${PASSWORD_EVOLVED}";
then
  if test "${DO_SU_UNDER_USER}" == "yes";
  then
    printf "%s\n" "su - \"${USER}\" -c \"${PG_BASEBACKUP_COMMAND_LINE}\""
    su - "${USER}" -c "${PG_BASEBACKUP_COMMAND_LINE}"
    PG_BASEBACKUP_EXIT="${?}"
  else
    printf "%s\n" "${PG_BASEBACKUP_COMMAND_LINE}"
    bash -c "${PG_BASEBACKUP_COMMAND_LINE}"
    PG_BASEBACKUP_EXIT="${?}"
  fi
else
  if test "${DO_SU_UNDER_USER}" == "yes";
  then
    printf "%s\n" "su - \"${USER}\" -c \"${PG_BASEBACKUP_COMMAND_LINE}\""
    printf "%s" "${PASSWORD_EVOLVED}" | su - "${USER}" -c "${PG_BASEBACKUP_COMMAND_LINE}"
    PG_BASEBACKUP_EXIT="${?}"
  else
    printf "%s\n" "${PG_BASEBACKUP_COMMAND_LINE}"
    printf "%s" "${PASSWORD_EVOLVED}" | bash -c "${PG_BASEBACKUP_COMMAND_LINE}"
    PG_BASEBACKUP_EXIT="${?}"
  fi
fi

if test "${PG_BASEBACKUP_EXIT}" -ne 0;
then
  alert "pg_basebackup failed. Backup will not be created"
  rm -rf "${TMP_DIR}"
  exit 1
fi

printf "%s\n" "Create backup archive from temporary directory:"
00-scripts/borg_backup_files.sh "${NAMEOFBACKUP}" --add-quoted "${TMP_DIR}" --prune "${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}" --prefix "${TYPEOFBACKUP}" --dont-ignore-missing-files
if test "${?}" -ne 0;
then
  alert "Cannot backup temporary directory '${TMP_DIR}'"
  rm -rf "${TMP_DIR}"
  exit 1
fi

printf "%s\n" "Remove temporary directory '${TMP_DIR}':"
rm -rf "${TMP_DIR}"
if test "${?}" -ne 0;
then
  alert "Cannot remove temporary directory '${TMP_DIR}'"
  exit 1
fi

exit 0
