#!/usr/bin/env bash

# Fallback way to back up MySQL

# Applicable when all of the following hold:
#   1. at least one table does NOT use the InnoDB engine
#   2. locking MySQL databases for the duration of the backup is acceptable
#   3. database size and other conditions allow the backup to finish
#      within the time allotted for this backup job

# How it works:
#   - run mysqldump and send the dump to stdout
#   - back up the dump with Borg reading from stdin

# Supported options:
# -c|--defaults-file         - path to the file with MySQL connection
#                              and runtime settings such as host,
#                              user, password, socket, etc. (mysqldump
#                              --defaults-file). If omitted, the file in
#                              ${DEFAULTS_FILE_DEFAULT} is used
# -d|--db                    - database name to back up;
#                              may be given more than once; all listed
#                              databases are included.
#                              If omitted, all databases are included,
#                              including system ones (mysql,
#                              information_schema, performance_schema)
# -a|--add-mysqldump-option  - extra option passed to
#                              mysqldump. If the mysqldump option has a value,
#                              pass it either with an equals sign
#                              ( = ) (long options only) or with a space,
#                              in which case the mysqldump option and its
#                              value must be wrapped in double or single quotes.
#                              For example:
#                               - --add-mysqldump-option --ignore-table=db1.table1
#                               - --add-mysqldump-option '--ignore-table db1.table1'
#                               - --add-mysqldump-option "--ignore-table db1.table1"
#                              May be given more than once;
#                              all listed options are passed to mysqldump
#                              The script always tries to add the options
#                              listed in ${DESIRED_OPTIONS}
# -k|--prune                 - retention options in Borg format, for
#                              example
#                              '--keep-hourly 72 --keep-within=30d'
#                              Optional; if omitted,
#                              ${CUSTOMPRUNE_DEFAULT} is used
# -s|--svcname               - service name string; used when the hostname
#                              changes. Optional;
#                              if omitted, $(hostname) is used
#                              for the backup repository name
#    --skip-hostname-prefix  - omit the '$(hostname)-' prefix from the
#                              Borg repository name. Optional


# Positional arguments:
# ${1} - job name, Borg repository name suffix; if omitted,
#        ${NAMEOFBACKUP_DEFAULT} is used

# The file given by --defaults-file must be owned by 'root:root' and
# have mode '0400'

# Install dependencies:
# - mysqldump:
#   - Debian/Ubuntu - sudo apt-get install mysql-client

# Schedule usage example:
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh 'MYSQLDUMP'
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf"'
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf" --db db1 --db db2'
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf" --db db1 --db db2 --add-mysqldump-option "--ignore-table db1.table1"'
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf" --db db1 --db db2 --add-mysqldump-option "--ignore-table db1.table1" --add-mysqldump-option --hex-blob'
# borg_run_on.sh 10.0.0.1 borg_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf" --db db1 --db db2 --add-mysqldump-option "--ignore-table db1.table1" --add-mysqldump-option --hex-blob --prune "--keep-hourly 3 --keep-within=30d"'

################################################################################

WORKDIR="$( dirname "${0}" )"
source "${WORKDIR}/../vars"

NAMEOFBACKUP_DEFAULT='MYSQLDUMP'
TYPEOFBACKUP='mysqldump'
DEFAULTS_FILE_DEFAULT='/etc/mysql/debian.cnf'
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=65d'

export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no -o StrictHostKeyChecking=no"

DESIRED_OPTIONS="
'--single-transaction'
'--routines'
"

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP:-${NAMEOFBACKUP_DEFAULT}}"
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"
  
  printf "%s\n" "ERROR: ${MESSAGE}"
  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

get_long_option_key()
{
  printf "%s\n" "${1}" | sed --quiet "s/$/=/;s/^[ \t]*--\([^= -][^= ][^= ]*\)[= ].*/\1/;p"
}

trim_trailing_single_quotes()
{
  printf "%s\n" "${1}" | sed --quiet "s/^'*//;s/'$//;p"
}

################################################################################

NAMEOFBACKUP=""
DEFAULTS_FILE=""
DBS=""
ADDITIONAL_OPTIONS=""
CUSTOMPRUNE=""

REPOSITORY=""
DBS_LINE=""
DATABASES_OPTION=""
EFFECTIVE_OPTIONS=""
MYSQLDUMP_HELP=""

# Parse command-line arguments
NORMALIZED_ARGS="$( getopt --options c:d:a:k:s: --longoptions ,defaults-file:,db:,add-mysqldump-option:,prune:,svcname:,skip-hostname-prefix -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -c|--defaults-file)         DEFAULTS_FILE="${2}";  shift 2;;
    -d|--db)                    
                                if test -z "${DBS}";
                                then
                                  DBS="'${2}'"
                                else
                                  DBS="${DBS}"$'\n'"'${2}'"
                                fi
                                
                                shift 2;;
    -a|--add-mysqldump-option)  
                                if test -z "${ADDITIONAL_OPTIONS}";
                                then
                                  ADDITIONAL_OPTIONS="'${2}'"
                                else
                                  ADDITIONAL_OPTIONS="${ADDITIONAL_OPTIONS}"$'\n'"'${2}'"
                                fi
                                
                                shift 2;;
                                
    -k|--prune)                 CUSTOMPRUNE="${2}";   shift 2;;
    -s|--svcname)               SVCNAME="${2}";   shift 2;;
    --skip-hostname-prefix)     DO_NOT_USE_HOSTNAME_IN_BORG_REPO_NAME="yes";  shift 1;;
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

if test -z "${SVCNAME}";
then
  SVCNAME="${$(hostname)}"
fi

REPOSITORY="${BORG_SERVER}:${SVCNAME}-${NAMEOFBACKUP}"

for db in ${DBS};
do
  if test "${db}" != "''";
  then
    DBS_LINE="${DBS_LINE} ${db}"
  fi
done

if test -z "${DBS_LINE}";
then
  DATABASES_OPTION="--all-databases"
else
  DATABASES_OPTION="--databases"
fi

MYSQLDUMP_HELP="$( mysqldump --help | sed --quiet "s/$/ /;p" )"

for option in ${DESIRED_OPTIONS};
do
  if test "${option}" != "''";
  then
    option_key=""
    option_key="$( get_long_option_key "$( trim_trailing_single_quotes "${option}" )" )"
    if test -n "$( printf "%s" "${MYSQLDUMP_HELP}" | grep "\-\-${option_key} " )" \
    -o -n "$( printf "%s" "${MYSQLDUMP_HELP}" | grep "\-\-${option_key}=" )" \
    -o -n "$( printf "%s" "${MYSQLDUMP_HELP}" | grep "\-\-${option_key}\[=.*\]" )";
    then
      EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
    else
      printf "%s\n" "WARNING: option --${option_key} not supported and skipped"
    fi
  fi
done

for option in ${ADDITIONAL_OPTIONS};
do
  if test "${option}" != "''";
  then
    EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
  fi
done

printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
borg init -e none "${REPOSITORY}"

MYSQLDUMP_COMMAND_LINE=\
"mysqldump --defaults-file='${DEFAULTS_FILE}' ${DATABASES_OPTION} ${EFFECTIVE_OPTIONS} ${DBS_LINE}"

BORG_COMMAND_LINE=\
"borg create --show-rc --stats \
'${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' -"

printf "%s\n" "Create backup archive:"
printf "%s\n" "${MYSQLDUMP_COMMAND_LINE} | ${BORG_COMMAND_LINE}"
bash -c "${MYSQLDUMP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"

CREATE_EXIT=( "${PIPESTATUS[@]}" )

if test "${CREATE_EXIT[0]}" -ne 0;
then
  alert "mysqldump failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped"
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
