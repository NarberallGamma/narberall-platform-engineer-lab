#!/usr/bin/env bash

# Primary backup method

# Applicable when (all of the following must hold):
#   1. innobackupex is available on the MySQL server node
#   2. every table in every MySQL database uses the InnoDB engine
#   3. when backing up from a slave, that slave is NOT running
#      DDL (schema changes), otherwise the backup will be inconsistent

# How it works:
#   - run innobackupex and send the dump to stdout
#   - back up the dump with Borg, reading the dump from stdin

# Supported options:
# -c|--defaults-file         -    path to the connection-parameter file for
#                                 the MySQL server (host,
#                                 user, password, socket, and similar (innobackupex option
#                                 --defaults-file). When omitted,
#                                 the file named in the variable
#                                 ${DEFAULTS_FILE_DEFAULT}
# -n|--ulimit-n                 - sets the maximum number of
#                                 simultaneously open file descriptors
#                                 for the process. When omitted,
#                                 the value from the variable
#                                 ${ULIMIT_N_DEFAULT}
# -a|--add-innobackupex-option  - extra option passed to
#                                 innobackupex. When an innobackupex option has
#                                 a value, pass it either with
#                                 an equals sign ( = ) (long options only),
#                                 long options), or as a space, but in
#                                 that case the innobackupex option together with its
#                                 the value must be wrapped in double or
#                                 single quotes. For example:
#                                   - --add-innobackupex-option --databases=db1
#                                   - --add-innobackupex-option '--databases db1'
#                                   - --add-innobackupex-option "---databases db1"
#                                 The option may be repeated,
#                                 innobackupex will receive all listed options
#                                 The script always adds --stream=xbstream
# -k|--prune                    - retention-options string
#                                 copies in Borg format, e.g.
#                                 '--keep-hourly 72 --keep-within=30d'
#                                 Optional. When omitted,
#                                 ${CUSTOMPRUNE_DEFAULT} is used

# Positional arguments:
# ${1} - job name, Borg repository name suffix. When omitted,
#        the name from ${NAMEOFBACKUP_DEFAULT} is used

# The file given by --defaults-file must be owned by 'root:root' and
# mode must be '0400'

# MYSQL8 dependency installation:
# - xtrabackup:
#   - Debian/Ubuntu - sudo apt-get install percona-xtrabackup-80

# Schedule example:
# borg_run_on.sh 10.0.0.1 borg_backup_mysql.sh
# borg_run_on.sh 10.0.0.1 borg_backup_mysql.sh 'MYSQL'
# borg_run_on.sh 10.0.0.1 borg_backup_mysql.sh 'MYSQL --defaults-file "/etc/mysql/debian.cnf"'
# borg_run_on.sh 10.0.0.1 borg_backup_mysql.sh 'MYSQL --defaults-file "/etc/mysql/debian.cnf" --ulimit-n 300000'
# borg_run_on.sh 10.0.0.1 borg_backup_mysql.sh 'MYSQL --defaults-file "/etc/mysql/debian.cnf" --ulimit-n 300000 --add-innobackupex-option "--databases \"db1 db2\""'
# borg_run_on.sh 10.0.0.1 borg_backup_mysql.sh 'MYSQL --defaults-file "/etc/mysql/debian.cnf" --ulimit-n 300000 --add-innobackupex-option "--databases \"db1 db2\"" --prune "--keep-hourly 3 --keep-within=30d"'


################################################################################

source vars

NAMEOFBACKUP_DEFAULT='MYSQL'
TYPEOFBACKUP='mysql'
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

# Parse command-line arguments
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

printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
borg init -e none "${REPOSITORY}"

ulimit -n "${ULIMIT_N_DEFAULT}"
if test "${?}" -ne 0;
then
  printf "%s\n" "WARNING: an error occurred while setting ulimit -n '${ULIMIT_N_DEFAULT}'"
fi

INNOBACKUPEX_COMMAND_LINE=\
"xtrabackup --defaults-file='${DEFAULTS_FILE}' ${EFFECTIVE_OPTIONS} --stream=xbstream --target-dir=./ --backup"

BORG_COMMAND_LINE=\
"borg create --show-rc --stats \
'${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' -"

printf "%s\n" "Create backup archive:"
printf "%s\n" "${INNOBACKUPEX_COMMAND_LINE} | ${BORG_COMMAND_LINE}"
bash -c "${INNOBACKUPEX_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"

CREATE_EXIT=( "${PIPESTATUS[@]}" )

if test "${CREATE_EXIT[0]}" -ne 0;
then
  alert "innobackupex failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped"
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
