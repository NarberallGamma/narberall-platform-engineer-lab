#!/usr/bin/env bash

# Fallback way to back up PostgreSQL

# How it works:
#   - run pg_basebackup, pack PostgreSQL data files into a tar archive on the fly, and store it in temporary directory ${TMP_DIR}
#   - back up the temporary directory with Borg

# Applicable when all of the following hold:
#   1. the PostgreSQL dump is smaller than the free space on the filesystem
#      that holds ${TMP_DIR}
#   2. the primary backup script borg_backup_postgres_stdout.sh cannot
#      be used in these conditions, for example:
#     2.1 network transfer from the PostgreSQL node to the Borg
#         backup store is slow enough that pg_basebackup
#         disconnects from PostgreSQL on timeout

# Supported options:
# -h|--host                      - PostgreSQL connection address. Optional
# -r|--port                      - PostgreSQL connection port. Optional
# -u|--user                      - username used to connect
#                                  to PostgreSQL or to run pg_basebackup. Optional;
#                                  if omitted,
#                                  ${USER_DEFAULT} is used
# -p|--password                  - path to the password file used to
#                                  connect to PostgreSQL, or the name of an
#                                  environment variable that holds that password. Optional
# -a|--add-pg_basebackup-option  - extra option passed to
#                                  pg_basebackup. If the pg_basebackup option has a
#                                  value, pass it either with an equals sign
#                                  ( = ) (long options only) or with a space,
#                                  in which case the pg_basebackup option and its
#                                  value must be wrapped in double or
#                                  single quotes. For example:
#                                   - --add-pg_basebackup-option --max-rate=1024
#                                   - --add-pg_basebackup-option '--max-rate 1024'
#                                   - --add-pg_basebackup-option "--max-rate 1024"
#                                  May be given more than once;
#                                  all listed options are passed to pg_basebackup.
#                                  Optional
# -k|--prune                     - retention options in Borg format, for
#                                  example '--keep-hourly 72 --keep-within=30d'
#                                  Optional; if omitted,
#                                  ${CUSTOMPRUNE_DEFAULT} is used
#    --do-su-under-user          - run pg_basebackup as the user given by
#                                  -u|--user or the default user. Useful when
#                                  the 'peer' authentication method in pg_hba.conf
#                                  must be used instead of 'trust'
#    --tmp-dir                   - temporary directory used to store
#                                  PostgreSQL data. Optional; if omitted,
#                                  ${TMP_DIR_DEFAULT} is used

# Positional arguments:
# ${1} - job name, Borg repository name suffix; if omitted,
#        ${NAMEOFBACKUP_DEFAULT} is used

# Schedule usage examples:
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh 'PG'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh 'PG --user postgres'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh 'PG --user postgres --do-su-under-user'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh 'PG --user postgres --do-su-under-user -a "--max-rate 1024" -a --progress'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh 'PG --user postgres --do-su-under-user -a "--max-rate 1024" -a --progress --prune "--keep-hourly 3 --keep-within=30d"'
# borg_run_on.sh 10.0.0.1 borg_backup_postgres.sh 'PG --host 127.0.0.1 --user pg_super --password "/etc/backup/pg-pass"'

# The [-p, --password] value must not be the password itself.
# Use one of:
#   - a path to a password file. The file must be owned by 'root:root' and
#     have mode '0400'
#   - the name of an environment variable that holds the password

# Using a temporary directory shallower than level 3, i.e. '/', '/etc',
# '/var', and similar, or any directory listed in ${PROTECTED_DIRS},
# aborts the script and produces no backups

# This script requires PostgreSQL to be configured as follows:
#   1. WAL generation is configured (file - postgresql.conf):
#     1.1 wal_level must be >= archive (leave it unchanged if it is already
#         >= archive)
#     1.2 wal_keep_segments must be > 0 (if it is already
#         > 0, change it only when there is a problem and only after agreeing with the team/client)
#         If this option is changed independently, pick a value
#         20-40% higher than the number of WAL files created
#         during the backup (provided the filesystem has enough
#         free space):
#        1.2.1 measure how long the backup takes
#        1.2.2 measure how many WAL files are generated in that time
#        1.2.3 set wal_keep_segments to (1.2 ~ 1.4) x (WAL files generated during the backup)
#        1.2.4 confirm that the filesystem that stores WAL files
#              has more free space than (wal_keep_segments x wal_segment_size)
#     1.3 max_wal_senders must be > 0 (recommended value is 5;
#         if it is already > 0, change it only when there is a problem and only
#         after agreeing with the team/client)
#     1.4 applying these parameters requires a PostgreSQL service restart
#   2. replication is allowed for the postgres system user from
#      127.0.0.1/32 or a Unix socket (file - pg_hba.conf):
#     2.1 an uncommented line must be present
#         host    replication     postgres        127.0.0.1/32            trust
#         or the line
#         local   replication     postgres                                trust
#     2.2 to apply these parameters, send PostgreSQL a signal to
#         reread the configuration file with
#         pg_ctlcluster <version> <cluster> reload,
#         where <version>, <cluster> are the PostgreSQL cluster version and name,
#         which can be listed with pg_lsclusters
#   3. PostgreSQL version is greater than or equal to 9.1

################################################################################

source vars

NAMEOFBACKUP_DEFAULT='PG'
TYPEOFBACKUP='PG'
USER_DEFAULT="postgres"
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=65d'
TMP_DIR_DEFAULT="/tmp/pg_basebackup"

export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no"

declare -A PG_BASEBACKUP_COMMON_OPTIONS
PG_BASEBACKUP_COMMON_OPTIONS['9']="--checkpoint=fast --format=tar --label=backup --xlog"
PG_BASEBACKUP_COMMON_OPTIONS['10']="--checkpoint=fast --format=tar --label=backup --wal-method=fetch"
PG_BASEBACKUP_COMMON_OPTIONS['11']="--checkpoint=fast --format=tar --label=backup --wal-method=fetch"

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

extract_version_string()
{
  printf "%s" "${1}" | grep --only-matching '[0-9][0-9]*\(\.[0-9][0-9]*\)\{1,\}' | head -n 1
}

get_major_version()
{
  printf "%s" "${1}" | sed --quiet "s/^\([0-9][0-9]*\)\..*/\1/;p"
}

# Compare VFS paths correctly
# uncertain - undefined state; one argument is not a VFS path
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

# Parse command-line arguments
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
