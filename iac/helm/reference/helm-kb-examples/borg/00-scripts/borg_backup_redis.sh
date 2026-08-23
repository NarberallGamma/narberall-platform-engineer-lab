#!/usr/bin/env bash

# FALLBACK Redis backup method, most often used when
# backing up Sentry

# The primary Redis backup method is calling 'borg_backup_files.sh' with
# a path to the Redis data directory, typically:
# borg_backup_files.sh 'REDIS /var/lib/redis'

# This script should not be used in most cases because of
# Redis doubling its RAM use during 'BGSAVE'
# Periodic execution of this operation is usually already configured in
# Redis setups, so Redis backup reduces
# to copying the Redis data directory into the backup repository

# Applicable when (all of the following must hold):
#   1. its use is explicitly approved by the team
#   2. redis-server is running on the same node where this script will run

# How it works:
#   - create a snapshot with 'redis-cli BGSAVE'
#   - back up the snapshot with borg_backup_files.sh '/var/lib/redis'

# Supported options:
# -n|--job-name - job name, Borg repository name suffix
# -h|--host     - redis-server connection address
# -r|--port     - redis-server connection port
# -s|--socket   - redis-server connection socket; when set it has
#                 higher priority than -h|--host and -r|--port
# -p|--password - path to the password file used to connect to
#                 redis-server, or the name of an environment variable that holds this password
# -t|--timeout  - BGSAVE wait limit in seconds,
#                 default 7200 seconds — 2 hours
# -k|--prune    - retention-options string in
#                 Borg format, e.g. '--keep-hourly 72 --keep-within=30d'
#                 Optional. When omitted,
#                 ${CUSTOMPRUNE_DEFAULT} is used

# Schedule examples:
# borg_run_on.sh 10.0.0.1 borg_backup_redis.sh '--job-name REDIS'
# borg_run_on.sh 10.0.0.1 borg_backup_redis.sh '--job-name REDIS --host 127.0.0.1 --port 6379'
# borg_run_on.sh 10.0.0.1 borg_backup_redis.sh '--job-name REDIS --host 127.0.0.1 --port 6379 --password REDIS_PASS_VAR'
# borg_run_on.sh 10.0.0.1 borg_backup_redis.sh '--job-name REDIS --host 127.0.0.1 --port 6379 --password REDIS_PASS_VAR --timeout 1800'
# borg_run_on.sh 10.0.0.1 borg_backup_redis.sh '--job-name REDIS --host 127.0.0.1 --port 6379 --password REDIS_PASS_VAR --timeout 1800 --prune "--keep-hourly 3 --keep-within=30d"'

# The value of [-p, --password] must not be
# the password itself. Pass one of:
#   - path to a password file. Owner must be 'root:root' and
#     mode must be '0400'
#   - the name of an environment variable that holds this password

################################################################################

NAMEOFBACKUP_DEFAULT='REDIS'
BGSAVE_TIMEOUT_DEFAULT='7200'
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=14d --keep-weekly=4 --keep-monthly=3'

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP:-${NAMEOFBACKUP_DEFAULT}}"
  CLUSTER=${CLUSTER:-unknown}
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"

  printf "%s\n" "ERROR: ${MESSAGE}"
  printf "%s\n" "${FULL_MESSAGE}"
  backup_notify --trigger backup --label cluster="${CLUSTER}" --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
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

# Parse command-line arguments
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
