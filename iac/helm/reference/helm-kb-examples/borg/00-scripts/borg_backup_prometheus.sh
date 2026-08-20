#!/usr/bin/env bash

# Этот скрипт - основной способ бэкапа Prometheus

# Его можно применять если (должны выполняться все условия):
#   1. Версия Prometheus >= 2.1
#   2. Prometheus должен быть запущен на том же узле на котором будет
#      запущен этот скрипт
#   3. Prometheus должен быть запущен с опцией --web.enable-admin-api

# Принцип работы:
#   - создание снимка, с помощью запроса к '/api/v1/admin/tsdb/snapshot', в подкаталоге 'snapshots'
#     каталога с данными Prometheus ( чаще всего каталог с данными - это каталог /var/prometheus/data/ )
#   - резервное копирование каталога /var/prometheus/data/snapshots/ с помощью скрипта borg_backup_files.sh
#   - удаление каталога /var/prometheus/data/snapshots/

# Поддерживаемые опции:
# -n|--job-name               - имя задания, суффикс имени Borg-репозитория. Необязательный
#                               аргумент, без указания будет использовано имя заданное в ${NAMEOFBACKUP_DEFAULT}
# -h|--host                   - адрес подключения к Prometheus. Необязательный аргумент,
#                               без указания будет использован адрес указанный в ${HOST_DEFAULT}
# -r|--port                   - порт подключения к Prometheus. Необязательный аргумент,
#                               без указания будет использован порт указанный в ${PORT_DEFAULT}
# -u|--user                   - имя пользователя, используемого для подключения
#                               к Prometheus. Необязательный аргумент
# -p|--password               - путь к файлу с паролем, используемым для
#                               подключения к Prometheus, или имя переменной
#                               окружения, содержащей этот пароль. Необязательный аргумент
# -t|--data-dir               - путь к каталогу с данными Prometheus. Необязательный аргумент,
#                               без указания будет использован путь указанный в ${DATA_DIR_DEFAULT}
# -l|--location               - location в HTTP-запросе к Prometheus выполняемого для создания снимка. Необязательный
#                               аргумент, без указания будет использован путь указанный в ${LOCATION_DEFAULT}
# -k|--prune                  - строка с опциями алгоритма сохранения резервных копий в
#                               формате программы Borg, например '--keep-hourly 72 --keep-within=30d'
#                               Необязательный аргумент, без указания этой опции будет
#                               использовано значение ${CUSTOMPRUNE_DEFAULT}

# Примеры использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_prometheus.sh
# borg_run_on.sh 10.0.0.1 borg_backup_prometheus.sh '--job-name "PRMTHS"'
# borg_run_on.sh 10.0.0.1 borg_backup_prometheus.sh '--job-name "PRMTHS" --data-dir "/var/prometheus/data/"'
# borg_run_on.sh 10.0.0.1 borg_backup_prometheus.sh '--job-name "PRMTHS" --data-dir "/var/prometheus/data/" --host "127.0.0.1" --port 9090'
# borg_run_on.sh 10.0.0.1 borg_backup_prometheus.sh '--job-name "PRMTHS" --data-dir "/var/prometheus/data/" --host "127.0.0.1" --port 9090 --prune "--keep-hourly 3 --keep-within=30d"'

# Запрещается указывать в качестве значения опции [-p, --password]
# непосредственно пароль. В качестве ее значения необходимо указать:
#   - путь к файлу с паролем. Владельцем этого файл должен быть 'root:root' и
#     для него должны быть установлены права '0400'
#   - имя переменной окружения, содержащей этот пароль

################################################################################

NAMEOFBACKUP_DEFAULT='PRMTHS'
TYPEOFBACKUP='PRMTHS'
SNAPSHOTS_DIR_NAME='snapshots'
HOST_DEFAULT='127.0.0.1'
PORT_DEFAULT='9090'
DATA_DIR_DEFAULT='/var/prometheus/data/'
LOCATION_DEFAULT='/api/v1/admin/tsdb/snapshot'
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=14d --keep-weekly=4 --keep-monthly=3'

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
  BACKUP_TYPE="${NAMEOFBACKUP}"
  CLUSTER=${CLUSTER:-unknown}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  printf "%s\n" "ERROR: ${MESSAGE}"
  backup_notify --trigger backup --label cluster="${CLUSTER}" --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

trim_trailing_single_quotes()
{
  printf "%s" "${1}" | sed --quiet "s/^'*//;s/'*$//;p"
}

trim_trailing_spaces()
{
  printf "%s" "${1}" | sed --quiet "s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;p"
}

#Удаляет избыточные символы '/' в строке
# ${1} - string
remove_repeating_vfs_divider()
{
  printf "%s" "${1}" | sed --quiet "s/\/\/*/\//g;p;"
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

check_snapshot_create_query_answer()
{
  printf "%s" "${1}" | tr '\n' ' ' | sed --quiet "/^ *{ *\"status\" *: *\"success\" *, *\"data\" *: *{ *\"name\" *: *\".*\" *} *} */I{;p}"
}

################################################################################

NAMEOFBACKUP=""
HOST=""
PORT=""
USER=""
PASSWORD=""
DATA_DIR=""
LOCATION=""
CUSTOMPRUNE=""

QUERY_URL=""
SNAPSHOTS_DIR=""
PASSWORD_EVOLVED=""

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options n:h:r:u:p:t:l:k: --longoptions ,job-name:,host:,port:,user:,password:,data-dir:,location:,prune: -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Exit"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -n|--job-name)                NAMEOFBACKUP="${2}"; shift 2;;
    -h|--host)                    HOST="${2}";         shift 2;;
    -r|--port)                    PORT="${2}";         shift 2;;
    -u|--user)                    USER="${2}";         shift 2;;
    -p|--password)                PASSWORD="${2}";     shift 2;;
    -t|--data-dir)                DATA_DIR="${2}";     shift 2;;
    -l|--location)                LOCATION="${2}";     shift 2;;
    -k|--prune)                   CUSTOMPRUNE="${2}";  shift 2;;
    *) break ;;
  esac
done

IFS=$'\n'

if test -z "${NAMEOFBACKUP}";
then
  printf "%s\n" "WARNING: job name is not defined, used default value '${NAMEOFBACKUP_DEFAULT}'"
  NAMEOFBACKUP="${NAMEOFBACKUP_DEFAULT}"
fi

if test -z "${LOCATION}";
then
  printf "%s\n" "WARNING: request location is not defined, used default value '${LOCATION_DEFAULT}'"
  LOCATION="${LOCATION_DEFAULT}"
fi

if test -z "${DATA_DIR}";
then
  printf "%s\n" "WARNING: Prometheus data directory is not defined, used default value '${DATA_DIR_DEFAULT}'"
  DATA_DIR="${DATA_DIR_DEFAULT}"
fi

if test ! -d "${DATA_DIR}";
then
  alert "Prometheus data directory does not exist"
  exit 1
fi
if test ! -r "${DATA_DIR}";
then
  alert "Prometheus data directory does not readable by this user"
  exit 1
fi
if test ! -x "${DATA_DIR}";
then
  alert "Prometheus data data directory does not executable by this user"
  exit 1
fi

if test -z "${HOST}";
then
  printf "%s\n" "WARNING: Prometheus host is not defined, used default value '${HOST_DEFAULT}'"
  HOST="${HOST_DEFAULT}"
fi

if test -z "${PORT}";
then
  printf "%s\n" "WARNING: Prometheus host is not defined, used default value '${HOST_DEFAULT}'"
  HOST="${HOST_DEFAULT}"
fi

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

QUERY_URL="
'http://${HOST}:${PORT}${LOCATION}'
'https://${HOST}:${PORT}${LOCATION}'
"

let snapshot_created=0
for url in ${QUERY_URL};
do
  CURL_COMMAND_LINE="curl --verbose --request POST "$( trim_trailing_single_quotes "${url}" )" --config -"

  printf "%s\n" "${CURL_COMMAND_LINE}"

  if test -n "${USER}" -o -n "${PASSWORD_EVOLVED}";
  then
    snapshot_create_query_answer="$( printf "%s" "--user \"${USER}:${PASSWORD_EVOLVED}\"" | bash -c "${CURL_COMMAND_LINE}" )"
  else
    snapshot_create_query_answer="$( printf "%s" "" | bash -c "${CURL_COMMAND_LINE}" )"
  fi

  snapshot_create_query_exit_value="${?}"

  if test "${snapshot_create_query_exit_value}" -eq 0 -a -n "$( check_snapshot_create_query_answer "${snapshot_create_query_answer}" )";
  then
    let snapshot_created+=1
    break
  fi
done

if test "${snapshot_created}" -eq 0;
then
  alert "Prometheus snapshot is not created"
  exit 1
fi

SNAPSHOTS_DIR="$( remove_repeating_vfs_divider "${DATA_DIR}/${SNAPSHOTS_DIR_NAME}" )"

if test ! -d "${SNAPSHOTS_DIR}";
then
  alert "Prometheus snapshots directory does not exist"
  exit 1
fi
if test ! -r "${SNAPSHOTS_DIR}";
then
  alert "Prometheus snapshots directory does not readable by this user"
  exit 1
fi
if test ! -x "${SNAPSHOTS_DIR}";
then
  alert "Prometheus snapshots directory does not executable by this user"
  exit 1
fi

00-scripts/borg_backup_files.sh "${NAMEOFBACKUP}" --add-quoted "${SNAPSHOTS_DIR}" --prune "${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}" --prefix "${TYPEOFBACKUP}" --dont-ignore-missing-files
if test "${?}" -ne 0;
then
  alert "Cannot backup Prometheus snapshots directory '${SNAPSHOTS_DIR}'. Snapshots directory will not be deleted"
  exit 1
fi

for dir in ${PROTECTED_DIRS};
do
  if test "$( compare_vfs_paths "${SNAPSHOTS_DIR}" "${dir}" )" == "equal" -o "$( compare_vfs_paths "${SNAPSHOTS_DIR}" "${dir}" )" == "uncertain";
  then
    alert "Directory '${dir}' is protected and can not be a directory with Prometheus snapshots. Snapshots directory will not be deleted"
    exit 1
  fi
done

if test "$( get_vfs_path_level "${SNAPSHOTS_DIR}" )" -le 2;
then
  alert "Prometheus snapshot directory level cannot be less that 2. Snapshots directory will not be deleted"
  exit 1
fi

if test "$( compare_vfs_paths "${SNAPSHOTS_DIR}" "${DATA_DIR}" )" == "equal";
then
  alert "For some reason, the directory with Prometheus snapshots was equal to the directory with Prometheus data. Snapshots directory will not be deleted"
  exit 1
fi

find "${SNAPSHOTS_DIR}" -delete
if test "${?}" -ne 0;
then
  alert "Cannot deleted Prometheus snapshots directory '${SNAPSHOTS_DIR}'"
  exit 1
fi

exit 0
