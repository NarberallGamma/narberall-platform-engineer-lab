#!/usr/bin/env bash

# This script is the primary Prometheus backup method

# Can be used when (all conditions must hold):
#   1. Prometheus version >= 2.1
#   2. Prometheus must be running on the same node where
#      this script will run
#   3. Prometheus must be started with --web.enable-admin-api

# How it works:
#   - create a snapshot via '/api/v1/admin/tsdb/snapshot' in the 'snapshots' subdirectory
#     of the Prometheus data directory (usually /var/prometheus/data/)
#   - back up /var/prometheus/data/snapshots/ with borg_backup_files.sh
#   - delete /var/prometheus/data/snapshots/

# Supported options:
# -n|--job-name               - job name, Borg repository name suffix. Optional
#                               argument; if omitted, the name set in ${NAMEOFBACKUP_DEFAULT} is used
# -h|--host                   - Prometheus connect address. Optional argument;
#                               if omitted, the address in ${HOST_DEFAULT} is used
# -r|--port                   - Prometheus connect port. Optional argument;
#                               if omitted, the port in ${PORT_DEFAULT} is used
# -u|--user                   - username used to connect
#                               to Prometheus. Optional argument
# -p|--password               - path to the password file used to
#                               connect to Prometheus, or the name of an environment
#                               variable that holds the password. Optional argument
# -t|--data-dir               - path to the Prometheus data directory. Optional argument;
#                               if omitted, the path in ${DATA_DIR_DEFAULT} is used
# -l|--location               - location in the Prometheus HTTP request used to create a snapshot. Optional
#                               argument; if omitted, the path in ${LOCATION_DEFAULT} is used
# -k|--prune                  - retention algorithm options string in 
#                               Borg format, for example '--keep-hourly 72 --keep-within=30d'
#                               Optional argument; if omitted, 
#                               the value of ${CUSTOMPRUNE_DEFAULT} is used

# Usage examples in schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_prometheus.sh
# borg_run_on.sh 10.0.0.1 borg_backup_prometheus.sh '--job-name "PRMTHS"'
# borg_run_on.sh 10.0.0.1 borg_backup_prometheus.sh '--job-name "PRMTHS" --data-dir "/var/prometheus/data/"'
# borg_run_on.sh 10.0.0.1 borg_backup_prometheus.sh '--job-name "PRMTHS" --data-dir "/var/prometheus/data/" --host "127.0.0.1" --port 9090'
# borg_run_on.sh 10.0.0.1 borg_backup_prometheus.sh '--job-name "PRMTHS" --data-dir "/var/prometheus/data/" --host "127.0.0.1" --port 9090 --prune "--keep-hourly 3 --keep-within=30d"'

# The [-p, --password] option must not be given 
# the password itself. Its value must be:
#   - a path to a password file. The file owner must be 'root:root' and 
#     its mode must be '0400'
#   - the name of an environment variable that holds the password

################################################################################

NAMEOFBACKUP_DEFAULT='PRMTHS'
TYPEOFBACKUP='PRMTHS'
SNAPSHOTS_DIR_NAME='snapshots'
HOST_DEFAULT='127.0.0.1'
PORT_DEFAULT='9090'
DATA_DIR_DEFAULT='/var/prometheus/data/'
LOCATION_DEFAULT='/api/v1/admin/tsdb/snapshot'
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=65d'

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
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"
  
  printf "%s\n" "ERROR: ${MESSAGE}"
  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

trim_trailing_single_quotes()
{
  printf "%s" "${1}" | sed --quiet "s/^'*//;s/'*$//;p"
}

trim_trailing_spaces()
{
  printf "%s" "${1}" | sed --quiet "s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;p"
}

# Remove extra '/' characters from the string
# ${1} - string
remove_repeating_vfs_divider()
{
  printf "%s" "${1}" | sed --quiet "s/\/\/*/\//g;p;"
}

# Compare VFS paths correctly
# uncertain - undefined state, one of the arguments is not a VFS path
# equal     - paths are equal
# not_equal - paths are not equal
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

# Determine the depth of the given path relative to the VFS root
# 0 - not a VFS path
# 1 - '/'
# 2 - '/etc', '/root', '/var', and similar
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

# Command-line argument parsing
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
