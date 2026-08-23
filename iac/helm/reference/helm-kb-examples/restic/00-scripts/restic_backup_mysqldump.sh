#!/usr/bin/env bash

# Fallback backup method for MySQL

# Applicable when (all of the following must hold):
#   1. at least one table does NOT use the InnoDB engine
#   2. locking MySQL databases for the duration of the backup is acceptable
#   3. MySQL database size and other conditions allow the backup to finish within the time 
#      allocated for this backup operation

# How it works:
#   - run mysqldump and send the dump to stdout
#   - back up the dump with restic, reading the dump from stdin

# Supported options:
# -c|--defaults-file         - path to the connection-parameter file for 
#                              the MySQL server (host, 
#                              user, password, socket, and similar (mysqldump option 
#                              --defaults-file). When omitted, 
#                              the file named in the variable 
#                              ${DEFAULTS_FILE_DEFAULT}
# -d|--db                    - database name to back up, 
#                              the option may be repeated; the 
#                              backup will include all listed databases. 
#                              When omitted, the backup 
#                              includes every database, including system ones ( mysql, 
#                              information_schema, performance_schema )
# -a|--add-mysqldump-option  - extra option passed to 
#                              mysqldump. When a mysqldump option has a value, 
#                              pass it either with an 
#                              equals sign ( = ) (long 
#                              options), or as a space, but in that case the option 
#                              mysqldump together with its value must 
#                              wrap in double or single quotes.
#                              For example:
#                               - --add-mysqldump-option --ignore-table=db1.table1
#                               - --add-mysqldump-option '--ignore-table db1.table1'
#                               - --add-mysqldump-option "--ignore-table db1.table1"
#                              The option may be repeated, 
#                              mysqldump will receive all listed options
#                              The script always tries to add the options 
#                              listed in ${DESIRED_OPTIONS}
# -k|--prune                 - retention-options string 
#                              copies in restic format, e.g. 
#                              '--keep-hourly 72 --keep-within 30d'
#                              Optional. When omitted, 
#                              ${CUSTOMPRUNE_DEFAULT} is used

# Positional arguments:
# ${1} - job name, restic repository tag. Required 

# The file given by --defaults-file must be owned by 'root:root' and 
# mode must be '0400'

# Dependency installation:
# - mysqldump:
#   - Debian/Ubuntu - sudo apt-get install mysql-client

# Schedule example:
# restic_run_on.sh 10.0.0.1 restic_backup_mysqldump.sh
# restic_run_on.sh 10.0.0.1 restic_backup_mysqldump.sh 'MYSQLDUMP'
# restic_run_on.sh 10.0.0.1 restic_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf"'
# restic_run_on.sh 10.0.0.1 restic_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf" --db db1 --db db2'
# restic_run_on.sh 10.0.0.1 restic_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf" --db db1 --db db2 --add-mysqldump-option "--ignore-table db1.table1"'
# restic_run_on.sh 10.0.0.1 restic_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf" --db db1 --db db2 --add-mysqldump-option "--ignore-table db1.table1" --add-mysqldump-option --hex-blob'
# restic_run_on.sh 10.0.0.1 restic_backup_mysqldump.sh 'MYSQLDUMP --defaults-file "/etc/mysql/debian.cnf" --db db1 --db db2 --add-mysqldump-option "--ignore-table db1.table1" --add-mysqldump-option --hex-blob --prune "--keep-hourly 3 --keep-within 2y5m7d3h"'

################################################################################

TYPEOFBACKUP='mysqldump'
DEFAULTS_FILE_DEFAULT='/etc/mysql/debian.cnf'
CUSTOMPRUNE_DEFAULT='--keep-hourly 1 --keep-within 65d'

DESIRED_OPTIONS="
'--single-transaction'
'--routines'
"

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP}"
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

DBS_LINE=""
DATABASES_OPTION=""
EFFECTIVE_OPTIONS=""
MYSQLDUMP_HELP=""

# Parse command-line arguments
NORMALIZED_ARGS="$( getopt --options c:d:a:k: --longoptions ,defaults-file:,db:,add-mysqldump-option:,prune: -- "${@}" 2>/dev/null )"
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
    *) break ;;
  esac
done

IFS=$'\n'

NAMEOFBACKUP="${2}"

if test -z "${NAMEOFBACKUP}";
then
  printf "%s\n" "WARNING: job name (tag) is not defined!"
  exit 1
fi

if test -z "${DEFAULTS_FILE}";
then
  printf "%s\n" "WARNING: defaults file is not defined, used default value '${DEFAULTS_FILE_DEFAULT}'"
  DEFAULTS_FILE="${DEFAULTS_FILE_DEFAULT}"
fi

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

printf "%s\n" "Initialize backup repository:"
restic init || echo "skip initialization."

MYSQLDUMP_COMMAND_LINE=\
"mysqldump --defaults-file='${DEFAULTS_FILE}' ${DATABASES_OPTION} ${EFFECTIVE_OPTIONS} ${DBS_LINE}"

RESTIC_COMMAND_LINE=\
"restic backup --verbose --stdin --stdin-filename ${NAMEOFBACKUP}.dump \
--tag ${NAMEOFBACKUP}"

printf "%s\n" "Create backup archive:"
printf "%s\n" "${MYSQLDUMP_COMMAND_LINE} | ${RESTIC_COMMAND_LINE}"
bash -c "${MYSQLDUMP_COMMAND_LINE}" | bash -c "${RESTIC_COMMAND_LINE}"

CREATE_EXIT=( "${PIPESTATUS[@]}" )

if test "${CREATE_EXIT[0]}" -ne 0;
then
  alert "mysqldump failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped"
  exit 1
fi

if test "${CREATE_EXIT[1]}" -ne 0;
then
  alert "restic backup failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped"
  exit 1
fi

PRUNE_COMMAND_LINE=\
"restic forget --prune --tag '${NAMEOFBACKUP}' \
${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}"

printf "%s\n" "Prune old backup archives:"
printf "%s\n" "${PRUNE_COMMAND_LINE}"
printf "%s\n" "${PRUNE_COMMAND_LINE}" | bash

PRUNE_EXIT="${?}"

if test "${PRUNE_EXIT}" -ne 0;
then
  alert "restic prune failed, exit code ${PRUNE_EXIT}"
  exit 1
fi

exit 0
