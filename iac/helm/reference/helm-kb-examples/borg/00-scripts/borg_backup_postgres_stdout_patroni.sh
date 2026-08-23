#!/usr/bin/env bash

# Primary backup method for PostgreSQL

# How it works:
#   - run pg_basebackup, streaming PostgreSQL data files into a tar archive on stdout
#   - back up the tar archive with Borg, reading it from stdin

# Supported options:
# -h|--host                      - PostgreSQL connection address. Optional
# -r|--port                      - PostgreSQL connection port. Optional
# -u|--user                      - username used to connect
#                                  to PostgreSQL or to run pg_basebackup. Optional
#                                  argument. When omitted,
#                                  value ${USER_DEFAULT}
# -p|--password                  - path to the password file used for
#                                  connecting to PostgreSQL, or the name of an environment
#                                  variable that holds this password. Optional
# -a|--add-pg_basebackup-option  - extra option passed to
#                                  pg_basebackup. When a pg_basebackup option has
#                                  a value, pass it either with
#                                  an equals sign ( = ) (long options only),
#                                  long options), or as a space, but in
#                                  that case the pg_basebackup option together with its
#                                  the value must be wrapped in double or
#                                  single quotes. For example:
#                                   - --add-pg_basebackup-option --max-rate=1024
#                                   - --add-pg_basebackup-option '--max-rate 1024'
#                                   - --add-pg_basebackup-option "--max-rate 1024"
#                                  The option may be repeated,
#                                  pg_basebackup will receive all listed options.
#                                  Optional
# -k|--prune                     - retention-options string in
#                                  Borg format, e.g. '--keep-hourly 72 --keep-within=30d'
#                                  Optional. When omitted,
#                                  ${CUSTOMPRUNE_DEFAULT} is used
#    --do-su-under-user          - run pg_basebackup as the user given
#                                  via -u|--user or the default user. Useful
#                                  when for some
#                                  reason 'trust' cannot be used and
#                                  use the 'peer' authentication method in pg_hba.conf
# -x|--patroni-port              - Patroni port. Default 8008

# Positional arguments:
# ${1} - job name, Borg repository name suffix. When omitted,
#        the name from ${NAMEOFBACKUP_DEFAULT} is used

# Schedule examples:
# borg_run_on.sh 10.0.0.1 borg_backup_postgres_stdout.sh
# borg_run_on.sh 10.0.0.1 borg_backup_postgres_stdout.sh 'PG'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres_stdout.sh 'PG --user postgres'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres_stdout.sh 'PG --user postgres --do-su-under-user'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres_stdout.sh 'PG --user postgres --do-su-under-user -a "--max-rate 1024" -a --progress'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres_stdout.sh 'PG --user postgres --do-su-under-user -a "--max-rate 1024" -a --progress --prune "--keep-hourly 3 --keep-within=30d"'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres_stdout.sh 'PG --host 127.0.0.1 --user pg_super --password "/etc/backup/pg-pass"'

# The value of [-p, --password] must not be
# the password itself. Pass one of:
#   - path to a password file. Owner must be 'root:root' and
#     mode must be '0400'
#   - the name of an environment variable that holds this password

# This script requires that PostgreSQL:
#   1. WAL file creation was configured (file: postgresql.conf):
#     1.1 wal_level must be >= archive (if it is already
#         >= archive — no change needed)
#     1.2 wal_keep_segments must be > 0 (if it is already
#         > 0 — change only when there are problems and only after agreeing with the team/client)
#         When changing this option independently, pick a value
#         about 20-40% larger than the number of WAL files created
#         during the backup (provided the filesystem has enough
#         free space):
#        1.2.1 measure backup duration
#        1.2.2 count WAL files generated during that time
#        1.2.3 set wal_keep_segments to (1.2 ~ 1.4) x (WAL files generated during the backup)
#        1.2.4 confirm that the filesystem that stores WAL files
#              free space is greater than (wal_keep_segments x wal_segment_size)
#     1.3 max_wal_senders must be > 0 (recommended value: 5,
#         if it is already > 0 — change only when there are problems and only after
#         agreeing with the team/client)
#     1.4 applying these settings requires a PostgreSQL service restart
#   2. replication was allowed for the postgres system user from
#      127.0.0.1/32 or a Unix socket (file: pg_hba.conf):
#     2.1 an uncommented line must be present
#         host    replication     postgres        127.0.0.1/32            trust
#         or the line
#         local   replication     postgres                                trust
#     2.2 applying these settings requires sending PostgreSQL a signal about
#         the need to reload the configuration file with
#         pg_ctlcluster <version> <cluster> reload,
#         where <version>, <cluster> are the PostgreSQL cluster version and name,
#         which can be obtained with pg_lsclusters
#   3. PostgreSQL version was 9.1 or newer

################################################################################

source vars

NAMEOFBACKUP_DEFAULT='PG'
TYPEOFBACKUP='PG'
USER_DEFAULT="postgres"
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=14d --keep-weekly=4 --keep-monthly=3'
PATRONI_PORT="8008"
ERRLOG=`mktemp`

export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no"

declare -A PG_BASEBACKUP_COMMON_OPTIONS
PG_BASEBACKUP_COMMON_OPTIONS['9']="--checkpoint=fast --format=tar --label=backup --xlog"
PG_BASEBACKUP_COMMON_OPTIONS['10']="--checkpoint=fast --format=tar --label=backup --wal-method=fetch"
PG_BASEBACKUP_COMMON_OPTIONS['11']="--checkpoint=fast --format=tar --label=backup --wal-method=fetch"
PG_BASEBACKUP_COMMON_OPTIONS['12']="--checkpoint=fast --format=tar --label=backup --wal-method=fetch"
PG_BASEBACKUP_COMMON_OPTIONS['13']="--checkpoint=fast --format=tar --label=backup --wal-method=fetch"
PG_BASEBACKUP_COMMON_OPTIONS['14']="--checkpoint=fast --format=tar --label=backup --wal-method=fetch"
PG_BASEBACKUP_COMMON_OPTIONS['15']="--checkpoint=fast --format=tar --label=backup --wal-method=fetch"
PG_BASEBACKUP_COMMON_OPTIONS['16']="--checkpoint=fast --format=tar --label=backup --wal-method=fetch"

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

################################################################################
NAMEOFBACKUP=""
HOST=""
PORT=""
USER=""
PASSWORD=""
ADDITIONAL_OPTIONS=""
CUSTOMPRUNE=""
CUSTOM_PATRONI_PORT=""
DO_SU_UNDER_USER=""

PASSWORD_EVOLVED=""
REPOSITORY=""
EFFECTIVE_OPTIONS=""
PG_BASEBACKUP_MAJOR_VERSION=""

# Parse command-line arguments
NORMALIZED_ARGS="$( getopt --options h:r:u:p:a:k:x: --longoptions ,host:,port:,user:,password:,add-pg_basebackup-option:,prune:,patroni-port:,do-su-under-user -- "${@}" 2>$ERRLOG )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created" "`cat $ERRLOG`"
  rm $ERRLOG
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
    -x|--patroni-port)              CUSTOM_PATRONI_PORT="${2}"; shift 2;;
       --do-su-under-user)          DO_SU_UNDER_USER="yes"; shift 1;;
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
  rm $ERRLOG
  exit 1
fi

if test -z "${PG_BASEBACKUP_COMMON_OPTIONS["${PG_BASEBACKUP_MAJOR_VERSION}"]}";
then
  alert "pg_basebackup have unsupported version. Backup will not be created"
  rm $ERRLOG
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

REPOSITORY="${BORG_SERVER}:${NAMEOFBACKUP}"

printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
borg init -e none "${REPOSITORY}"

PG_BASEBACKUP_COMMAND_LINE=\
"pg_basebackup ${EFFECTIVE_OPTIONS} --pgdata=- 2>>$ERRLOG"

BORG_COMMAND_LINE=\
"borg create --show-rc --stats \
'${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' -"

p_port=${CUSTOM_PATRONI_PORT:-${PATRONI_PORT}}
ip_port=$(ss -tnlp | grep $p_port | awk '{print $4}')
role=$(curl -s $ip_port | jq -r .role)

if [[ "$role" == "replica" ]]; then

  printf "%s\n" "Create backup archive:"

  if test "${DO_SU_UNDER_USER}" == "yes";
  then
    GROUP=$(id -gn "${USER}")
    chgrp "${GROUP}" "${ERRLOG}" && chmod 660 "${ERRLOG}"
  fi

  if test -z "${PASSWORD_EVOLVED}";
  then
    if test "${DO_SU_UNDER_USER}" == "yes";
    then
      printf "%s\n" "su - \"${USER}\" -c \"${PG_BASEBACKUP_COMMAND_LINE}\" | ${BORG_COMMAND_LINE}"
      su - "${USER}" -c "${PG_BASEBACKUP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
    else
      printf "%s\n" "${PG_BASEBACKUP_COMMAND_LINE} | ${BORG_COMMAND_LINE}"
      bash -c "${PG_BASEBACKUP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
    fi

    CREATE_EXIT=( "${PIPESTATUS[@]}" )

    if test "${CREATE_EXIT[0]}" -ne 0;
    then
      alert "pg_basebackup failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped" "`cat $ERRLOG`"
      rm $ERRLOG
      exit 1
    fi

    if test "${CREATE_EXIT[1]}" -ne 0;
    then
      alert "borg create failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped" "`cat $ERRLOG`"
      rm $ERRLOG
      exit 1
    fi
  else
    if test "${DO_SU_UNDER_USER}" == "yes";
    then
      printf "%s\n" "su - \"${USER}\" -c \"${PG_BASEBACKUP_COMMAND_LINE}\" | ${BORG_COMMAND_LINE}"
      printf "%s" "${PASSWORD_EVOLVED}" | su - "${USER}" -c "${PG_BASEBACKUP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
    else
      printf "%s\n" "${PG_BASEBACKUP_COMMAND_LINE} | ${BORG_COMMAND_LINE}"
      printf "%s" "${PASSWORD_EVOLVED}" | bash -c "${PG_BASEBACKUP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
    fi

    CREATE_EXIT=( "${PIPESTATUS[@]}" )

    if test "${CREATE_EXIT[1]}" -ne 0;
    then
      alert "pg_basebackup failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped" "`cat $ERRLOG`"
      rm $ERRLOG
      exit 1
    fi

    if test "${CREATE_EXIT[2]}" -ne 0;
    then
      alert "borg create failed, exit code ${CREATE_EXIT[2]}. Pruning of old archives skipped" "`cat $ERRLOG`"
      rm $ERRLOG
      exit 1
    fi
  fi

  PRUNE_COMMAND_LINE="borg prune --show-rc --list '${REPOSITORY}' \
  ${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}} 2>>$ERRLOG"

  printf "%s\n" "Prune old backup archives:"
  printf "%s\n" "${PRUNE_COMMAND_LINE}"
  printf "%s\n" "${PRUNE_COMMAND_LINE}" | bash

  PRUNE_EXIT="${?}"

  if test "${PRUNE_EXIT}" -ne 0;
  then
    alert "borg prune failed, exit code ${PRUNE_EXIT}" "`cat $ERRLOG`"
    rm $ERRLOG
    exit 1
  fi

  rm $ERRLOG

  exit 0

else
  echo "This is master, skipping backup pgsql"
fi

exit 0