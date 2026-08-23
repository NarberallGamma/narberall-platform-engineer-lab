#!/usr/bin/env bash

# This script is the primary Mongo backup method

# How it works:
#   - invoke mongodump and stream the dump to stdout
#   - back up the dump with borg, reading the dump from stdin

# Supported options:
# -h|--host                      - Mongo connect address. Required argument;
#                                  for backward compatibility the address may
#                                  still be given as the second (${2}) positional
#                                  argument. This option takes precedence over
#                                  the positional argument
# -r|--port                      - Mongo connect port. Optional argument
# -u|--user                      - username used to connect to Mongo.
#                                  Optional argument; if omitted,
#                                  the value of ${USER_DEFAULT} is used
# -p|--password                  - path to the password file used to connect to
#                                  Mongo, or the name of an environment
#                                  variable that holds the password. Optional argument
#    --authenticationDatabase    - database that stores authentication settings.
#                                  Optional argument; if omitted,
#                                  the value of ${AUTH_DATABASE_DEFAULT} is used
# -a|--add-mongodump-option      - extra option passed to mongodump. If the
#                                  mongodump option has a value, pass it with
#                                  an equals sign ( = ) (long options only) or a
#                                  space; in the space form, quote the option and
#                                  its value in double or single quotes. Examples:
#                                   - --add-mongodump-option --db=db1
#                                   - --add-mongodump-option '--db db1'
#                                   - --add-mongodump-option "--db db1"
#                                  The option may be given several times; all
#                                  listed options are passed to mongodump.
#                                  Optional argument
# -k|--prune                     - retention algorithm options string in
#                                  Borg format, for example '--keep-hourly 72 --keep-within=30d'
#                                  Optional argument; if omitted,
#                                  the value of ${CUSTOMPRUNE_DEFAULT} is used
#    --skip-hostname-prefix      - omit the '$(hostname)-' prefix from
#                                  the Borg repository name. Optional argument

# Positional arguments:
# ${1} - job name, Borg repository name suffix (without --skip-hostname-prefix)
# or the full Borg repository name (with --skip-hostname-prefix). Required argument
# ${2} - Mongo connect address. Required argument if -h|--host is not used

# Usage examples in schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_mongo.sh 'MONGO 127.0.0.1'
# borg_run_on.sh 10.0.0.1 borg_backup_mongo.sh 'MONGO --host 127.0.0.1'
# borg_run_on.sh 10.0.0.1 borg_backup_mongo.sh 'MONGO --host 127.0.0.1 --port 27017'
# borg_run_on.sh 10.0.0.1 borg_backup_mongo.sh 'MONGO --host 127.0.0.1 --port 27017 --password "/etc/backup/mongo-pass"'
# borg_run_on.sh 10.0.0.1 borg_backup_mongo.sh 'MONGO --host 127.0.0.1 --port 27017 --password "/etc/backup/mongo-pass" --user admin'
# borg_run_on.sh 10.0.0.1 borg_backup_mongo.sh 'MONGO --host 127.0.0.1 --port 27017 --password "/etc/backup/mongo-pass" --user admin --authenticationDatabase admin'
# borg_run_on.sh 10.0.0.1 borg_backup_mongo.sh 'MONGO --host 127.0.0.1 --port 27017 --password "/etc/backup/mongo-pass" --add-mongodump-option "--db test"'
# borg_run_on.sh 10.0.0.1 borg_backup_mongo.sh 'MONGO --host 127.0.0.1 --port 27017 --password "/etc/backup/mongo-pass" --prune "--keep-hourly 3 --keep-within=30d"'
# wrapper_ssh-agent.sh  ${CI_PROJECT_DIR}/00-scripts/borg_backup_mongo.sh 'distinguished-name-MONGO --host 192.168.0.1 --port 27017 --password "/etc/backup/mongo-pass"'
# wrapper_ssh-agent.sh  /app/00-scripts/borg_backup_mongo.sh 'distinguished-name-MONGO --host 192.168.0.1 --port 27017 --password "/etc/backup/mongo-pass"'

# The [-p, --password] option must not be given
# the password itself. Its value must be:
#   - a path to a password file. The file owner must be 'root:root' and
#     its mode must be '0400'
#   - the name of an environment variable that holds the password

################################################################################

WORKDIR="$( dirname "${0}" )"
source "${WORKDIR}/../vars"

TYPEOFBACKUP='files'
USER_DEFAULT="admin"
AUTH_DATABASE_DEFAULT="admin"
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=65d'

export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no -o StrictHostKeyChecking=no"

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP:-${NAMEOFBACKUP_DEFAULT}}"
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"
  
  printf "%s\n" "ERROR: ${MESSAGE}"
  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
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

################################################################################
NAMEOFBACKUP=""
HOST=""
PORT=""
USER=""
PASSWORD=""
AUTH_DATABASE=""
ADDITIONAL_OPTIONS=""
CUSTOMPRUNE=""
DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME=""

PASSWORD_EVOLVED=""
REPOSITORY=""
EFFECTIVE_OPTIONS=""

# Command-line argument parsing
NORMALIZED_ARGS="$( getopt --options h:r:u:p:a:k: --longoptions ,host:,port:,user:,password:,authenticationDatabase:,add-mongodump-option:,prune:,skip-hostname-prefix -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -h|--host)                    HOST="${2}";              shift 2;;
    -r|--port)                    PORT="${2}";              shift 2;;
    -u|--user)                    USER="${2}";              shift 2;;
    -p|--password)                PASSWORD="${2}";          shift 2;;
       --authenticationDatabase)  AUTH_DATABASE="${2}";     shift 2;;
    -a|--add-mongodump-option)    
                                  if test -z "${ADDITIONAL_OPTIONS}";
                                  then
                                    ADDITIONAL_OPTIONS="'${2}'"
                                  else
                                    ADDITIONAL_OPTIONS="${ADDITIONAL_OPTIONS}"$'\n'"'${2}'"
                                  fi
                                  
                                  shift 2;;
                                  
    -k|--prune)                   CUSTOMPRUNE="${2}";                           shift 2;;
       --skip-hostname-prefix)    DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME="yes";  shift 1;;
    *) break ;;
  esac
done

IFS=$'\n'

NAMEOFBACKUP="${2}"
if test -z "${HOST}";
then
  HOST="${3}"
fi

if test -z "${NAMEOFBACKUP}";
then
  alert "Backup job name is not defined. Backup will not be created"
  exit 1
fi

if test -z "${HOST}";
then
  alert "Mongo host is not defined. Backup will not be created"
  exit 1
fi

EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --host '${HOST}'"

if test -n "${PORT}";
then
  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --port '${PORT}'"
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
  if test -z "${USER}";
  then
    printf "%s\n" "WARNING: user name is not defined, used default value '${USER_DEFAULT}'"
    USER="${USER_DEFAULT}"
  fi
  
  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --username '${USER}'"
  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --password ''"
  
  if test -z "${AUTH_DATABASE}";
  then
    printf "%s\n" "WARNING: authentication database is not defined, used default value '${AUTH_DATABASE_DEFAULT}'"
    AUTH_DATABASE="${AUTH_DATABASE_DEFAULT}"
  fi
  
  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --authenticationDatabase '${AUTH_DATABASE}'"
fi

for option in ${ADDITIONAL_OPTIONS};
do
  if test "${option}" != "''";
  then
    EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
  fi
done

EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --archive"

if test "${DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME}" == "yes";
then
  REPOSITORY="${BORG_SERVER}:${NAMEOFBACKUP}"
else
  REPOSITORY="${BORG_SERVER}:$(hostname)-${NAMEOFBACKUP}"
fi

printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
borg init -e none "${REPOSITORY}"

MONGODUMP_COMMAND_LINE=\
"mongodump ${EFFECTIVE_OPTIONS}"

BORG_COMMAND_LINE=\
"borg create --show-rc --stats \
'${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' -"

if test -z "${PASSWORD_EVOLVED}";
then
  printf "%s\n" "${MONGODUMP_COMMAND_LINE} | ${BORG_COMMAND_LINE}"
  bash -c "${MONGODUMP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
  
  CREATE_EXIT=( "${PIPESTATUS[@]}" )
  
  if test "${CREATE_EXIT[0]}" -ne 0;
  then
    alert "mongodump failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped"
    exit 1
  fi
  
  if test "${CREATE_EXIT[1]}" -ne 0;
  then
    alert "borg create failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped"
    exit 1
  fi
else
  printf "%s\n" "${MONGODUMP_COMMAND_LINE} | ${BORG_COMMAND_LINE}"
  printf "%s\n" "${PASSWORD_EVOLVED}" | bash -c "${MONGODUMP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
  
  CREATE_EXIT=( "${PIPESTATUS[@]}" )
  
  if test "${CREATE_EXIT[1]}" -ne 0;
  then
    alert "mongodump failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped"
    exit 1
  fi
  
  if test "${CREATE_EXIT[2]}" -ne 0;
  then
    alert "borg create failed, exit code ${CREATE_EXIT[2]}. Pruning of old archives skipped"
    exit 1
  fi
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
