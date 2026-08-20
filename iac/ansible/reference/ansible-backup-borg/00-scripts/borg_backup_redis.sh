#!/usr/bin/env bash

# Этот скрипт - ЗАПАСНОЙ способ бэкапа Redis, чаще всего применяемый при 
# резервном копировании Sentry

# Основной способ бэкапа Redis - это вызов скрипта 'borg_backup_files.sh' с 
# указанием пути к каталогу с данными Redis, как правило вот так:
# borg_backup_files.sh 'REDIS /var/lib/redis'

# Причина по которой этот скрипт не следует применять в большинстве случаев - 
# двукратное потребление ОЗУ процессом Redis во время операции 'BGSAVE'
# Как правило, периодическое выполнение этой операции уже настроено в 
# установках Redis и, соответственно, резервное копирование Redis сводится 
# к копированию содержимого каталога с данными Redis в репозиторий бэкапов

# Его можно применять если (должны выполняться все условия):
#   1. его применение явно разрешено командой
#   2. redis-server запущен на том же узле на котором будет запущен этот скрипт

# Принцип работы:
#   - создание снимка с помощью 'redis-cli BGSAVE'
#   - резервное копирование снимка с помощью borg_backup_files.sh '/var/lib/redis'

# Поддерживаемые опции:
# -n|--job-name - имя задания, суффикс имени Borg-репозитория
# -h|--host     - адрес подключения к redis-server
# -r|--port     - порт подключения к redis-server
# -s|--socket   - сокет подключения к redis-server, если указан имеет более 
#                 высокий приоритет чем -h|--host и -r|--port
# -p|--password - путь к файлу с паролем, используемым для подключения к 
#                 redis-server, или имя переменной окружения, содержащей этот пароль
# -t|--timeout  - предел времени ожидания завершения операции BGSAVE в секундах, 
#                 по умолчанию 7200 секунд - 2 часа
# -k|--prune    - строка с опциями алгоритма сохранения резервных копий в 
#                 формате программы Borg, например '--keep-hourly 72 --keep-within=30d'
#                 Необязательный аргумент, без указания этой опции будет 
#                 использовано значение ${CUSTOMPRUNE_DEFAULT}

# Примеры использования в schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_redis.sh '--job-name REDIS'
# borg_run_on.sh 10.0.0.1 borg_backup_redis.sh '--job-name REDIS --host 127.0.0.1 --port 6379'
# borg_run_on.sh 10.0.0.1 borg_backup_redis.sh '--job-name REDIS --host 127.0.0.1 --port 6379 --password REDIS_PASS_VAR'
# borg_run_on.sh 10.0.0.1 borg_backup_redis.sh '--job-name REDIS --host 127.0.0.1 --port 6379 --password REDIS_PASS_VAR --timeout 1800'
# borg_run_on.sh 10.0.0.1 borg_backup_redis.sh '--job-name REDIS --host 127.0.0.1 --port 6379 --password REDIS_PASS_VAR --timeout 1800 --prune "--keep-hourly 3 --keep-within=30d"'

# Запрещается указывать в качестве значения опции [-p, --password] 
# непосредственно пароль. В качестве ее значения необходимо указать:
#   - путь к файлу с паролем. Владельцем этого файл должен быть 'root:root' и 
#     для него должны быть установлены права '0400'
#   - имя переменной окружения, содержащей этот пароль

################################################################################

NAMEOFBACKUP_DEFAULT='REDIS'
BGSAVE_TIMEOUT_DEFAULT='7200'
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=65d'

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP:-${NAMEOFBACKUP_DEFAULT}}"
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"
  
  printf "%s\n" "ERROR: ${MESSAGE}"
  printf "%s\n" "${FULL_MESSAGE}"
  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

check_to_positive_number_format()
{
  if test -n "${1}";
  then
    if test -n "$( printf "%s" "${1}" | sed --quiet "s/\([1-9]\{1,1\}\)\|\(^[1-9][0-9]*\)//;p;" )";
    then
      return 1
    fi
  else
    return 1
  fi
  
  return 0
}

trim_trailing_spaces()
{
  printf "%s" "${1}" | sed --quiet "s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;p"
}

get_env_var_value()
{
  if test -n "${1}";
  then
    printenv | grep --fixed-regexp "${1}=" | sed --quiet "s/[^=]*=//;s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;s/\r//g;p"
  fi
}

parse_redis_config_get_dir_answer()
{
  local f_line
  local s_line
  
  f_line="$( printf "%s" "${1}" | head -n 1 )"
  s_line="$( printf "%s" "${1}" | tail -n +2 | head -n 1 )"
  
  if test "${f_line}" != "dir";
  then
    printf "%s" ""
    return 1
  fi
  
  printf "%s" "${s_line}"
  return 0
}

################################################################################

NAMEOFBACKUP=""
HOST=""
PORT=""
SOCKET=""
PASSWORD=""
BGSAVE_TIMEOUT="${BGSAVE_TIMEOUT_DEFAULT}"
CUSTOMPRUNE=""

CONNECTION_STRING=""
PASSWORD_EVOLVED=""
DATA_DIR=""

#Разбор аргументов командной строки
NORMALIZED_ARGS="$( getopt --options n:h:r:s:p:t:k: --longoptions ,job-name:,host:,port:,socket:,password:,timeout:,prune: -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Exit"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -n|--job-name)  NAMEOFBACKUP="${2}";    shift 2;;
    -h|--host)      HOST="${2}";            shift 2;;
    -r|--port)      PORT="${2}";            shift 2;;
    -s|--socket)    SOCKET="${2}";          shift 2;;
    -p|--password)  PASSWORD="${2}";        shift 2;;
    -t|--timeout)   BGSAVE_TIMEOUT="${2}";  shift 2;;
    -k|--prune)     CUSTOMPRUNE="${2}";     shift 2;;
    *) break ;;
  esac
done

IFS=$'\n'

if test -z "${NAMEOFBACKUP}";
then
  printf "%s\n" "WARNING: job name is not defined, used default value '${NAMEOFBACKUP_DEFAULT}'"
  NAMEOFBACKUP="${NAMEOFBACKUP_DEFAULT}"
fi

if test -n "${SOCKET}";
then
  if test -S "${SOCKET}";
  then
    CONNECTION_STRING="${CONNECTION_STRING} -s '${SOCKET}'"
    
    if test -n "${HOST}";
    then
      printf "%s\n" "WARNING: options --socket and --host are simultaneously defined. Will be used --socket option"
    fi
    if test -n "${PORT}";
    then
      printf "%s\n" "WARNING: options --socket and --port are simultaneously defined. Will be used --socket option"
    fi
  else
    printf "%s\n" "WARNING: option --socket is defined but '${SOCKET}' does not exits. Will be used values of --host and --port options or try without anything"
    SOCKET=""
  fi
fi

if test -z "${SOCKET}";
then
  if test -n "${HOST}";
  then
    CONNECTION_STRING="${CONNECTION_STRING} -h '${HOST}'"
  fi
  
  if test -n "${PORT}";
  then
    CONNECTION_STRING="${CONNECTION_STRING} -p '${PORT}'"
  fi
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

if test -n "${PASSWORD_EVOLVED}";
then
  CONNECTION_STRING="${CONNECTION_STRING} -a '${PASSWORD_EVOLVED}'"
fi

check_to_positive_number_format "${BGSAVE_TIMEOUT}"
if test "${?}" -ne 0;
then
  printf "%s\n" "WARNING: value of --timeout option '${BGSAVE_TIMEOUT}' is not numeric or less than 1. Used default value '${BGSAVE_TIMEOUT_DEFAULT}' seconds"
  BGSAVE_TIMEOUT="${BGSAVE_TIMEOUT_DEFAULT}"
fi

printf "%s\n" "Determining Redis data directory:"

DATA_DIR="$( echo "redis-cli ${CONNECTION_STRING} CONFIG GET dir" | bash )"
DATA_DIR="$( parse_redis_config_get_dir_answer "${DATA_DIR}" )"

if test -z "${DATA_DIR}";
then
  alert "Cannot determine Redis data directory"
  exit 1
fi

if test ! -e "${DATA_DIR}";
then
  alert "Redis data directory does not exists"
  exit 1
fi

if test ! -d "${DATA_DIR}";
then
  alert "Name of Redis data directory in use but is not a directory"
  exit 1
fi

if test ! -r "${DATA_DIR}";
then
  alert "Redis data directory does not readable by this user"
  exit 1
fi

if test ! -x "${DATA_DIR}";
then
  alert "Redis data directory does not executable by this user"
  exit 1
fi

printf "%s\n" "Redis data directory is '${DATA_DIR}'"

printf "%s\n" "Saving dataset producing to snapshot:"

lastsave_before_bgsave=""
lastsave_before_bgsave="$( echo "redis-cli ${CONNECTION_STRING} LASTSAVE" | bash )"

lastsave_test="$( date --date "@${lastsave_before_bgsave}" )"
if test "${?}" -ne 0;
then
  alert "Cannot determine date of last successfully saved snapshot before saving new snapshot"
  exit 1
fi

start_date=""
start_date="$( date +"%s" )"
if test "${?}" -ne 0 -o -z "${start_date}";
then
  alert "Cannot determine current date before saving new snapshot"
  exit 1
fi

echo "redis-cli ${CONNECTION_STRING} BGSAVE" | bash

lastsave_after_bgsave=""
while true;
do
  sleep 5
  
  lastsave_after_bgsave="$( echo "redis-cli ${CONNECTION_STRING} LASTSAVE" | bash )"
  
  lastsave_test="$( date --date "@${lastsave_after_bgsave}" )"
  if test "${?}" -ne 0;
  then
    alert "Cannot determine date of last successfully saved snapshot after start saving new snapshot"
    exit 1
  fi
  
  if test "${lastsave_after_bgsave}" -gt "${lastsave_before_bgsave}";
  then
    printf "%s\n" "Saving dataset producing to snapshot is successful"
    break
  fi
  
  current_date=""
  current_date="$( date +"%s" )"
  if test "${?}" -ne 0 -o -z "${current_date}";
  then
    alert "Cannot determine current date in wait loop after start saving new snapshot"
    exit 1
  fi
  
  let diff_of_dates=current_date-start_date
  
  if test "${diff_of_dates}" -lt 0;
  then
    alert "Cannot calculate wait timeout"
    exit 1
  fi
  
  if test "${diff_of_dates}" -ge "${BGSAVE_TIMEOUT}";
  then
    alert "BGSAVE wait timeout reached"
    exit 1
  fi
done

printf "%s\n" "Backup Redis data directory:"

00-scripts/borg_backup_files.sh "${NAMEOFBACKUP}" "${DATA_DIR}" --prune "${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}" --dont-ignore-missing-files
if test "${?}" -ne 0;
then
  alert "Cannot backup Redis data directory '${DATA_DIR}'"
  exit 1
fi

printf "%s\n" "Backup Redis data directory is successful"
exit 0
