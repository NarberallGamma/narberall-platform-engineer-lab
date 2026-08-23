#!/usr/bin/env bash

# This script is the primary way to back up files

# How it works:
#   - create a backup of files and/or directories in a Borg repository with 
#     'borg create'
#   - delete old backups in the Borg repository with 'borg prune'

# Supported options:
# -q|--add-quoted                - path to a file or directory to
#                                  include. The option may be given several times;
#                                  all listed files and/or directories enter the backup.
#                                  Paths are wrapped in single quotes — paths with spaces
#                                  are handled correctly, but wildcard expansion will not
#                                  work. Optional argument; paths to
#                                  files and/or directories must be given either with
#                                  this option or with positional argument ${2};
#                                  both may be used together
# -k|--prune                     - retention algorithm options string in 
#                                  Borg format, for example '--keep-hourly 72 --keep-within=30d'
#                                  Optional argument; if omitted, 
#                                  the value of ${CUSTOMPRUNE_DEFAULT} is used
#    --prefix                    - string placed before the archive name with a '-',
#                                  for example 'PG-', 'files-'. Optional argument; if omitted,
#                                  the value of ${TYPEOFBACKUP_DEFAULT} is used
#    --dont-ignore-missing-files - by default the script does not treat sudden
#                                  disappearance or loss of access to target files
#                                  or directories (and files and directories inside
#                                  those directories) as errors, i.e. it ignores
#                                  '[Errno 2] No such file or directory' and '[Errno 13] Permission denied'.
#                                  This option disables ignoring
#                                  those errors. When it is used the script
#                                  returns a non-zero status and sends
#                                  an alert, same as for other, more serious errors

# Positional arguments:
# ${1} - job name, Borg repository name suffix. Required argument
# ${2} - comma-separated paths to files or directories to
#        back up. Wildcards may be used; spaces in
#        paths will NOT be handled correctly. Required argument if
#        -q|--add-quoted is unused, or exclusions must be set
#        via positional argument ${3}
# ${3} - backup exclusions as regular expressions.
#        Several regular expressions may be given, comma-separated.
#        Optional argument

# Usage examples in schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_files.sh 'SYSTEM /etc,/var/spool/cron,/etc/backup-agent/config.d ^\/etc\/\.git$'
# borg_run_on.sh 10.0.0.1 borg_backup_files.sh 'DATA /var ^\/var\/.*\/lock$'
# borg_run_on.sh 10.0.0.1 borg_backup_files.sh 'DATA /var ^\/var\/.*\/lock$,^\/var\/log/auth.log.*$'
# borg_run_on.sh 10.0.0.1 borg_backup_files.sh 'DATA /var ^\/var\/.*\/lock$,^\/var\/log/auth.log.*$ --prune "--keep-hourly 3 --keep-within=30d"'
# borg_run_on.sh 10.0.0.1 borg_backup_files.sh 'LOGS /var/log/auth.log*,/var/log/wtmp* --add-quoted "/var/log/apt" --add-quoted "/var/log/cups"'

################################################################################

source vars

TYPEOFBACKUP_DEFAULT='files'
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=65d'

export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no"

################################################################################

function alert {
  BACKUP_TARGET="$( hostname )"
  BACKUP_TYPE="${NAMEOFBACKUP}"
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"
  
  printf "%s\n" "ERROR: ${MESSAGE}"
  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
}

################################################################################

DIRS_QUOTED=""
CUSTOMPRUNE=""
TYPEOFBACKUP=""
DONT_IGNORE_MISSING_FILES=""

# Command-line argument parsing
NORMALIZED_ARGS="$( getopt --options q:k: --longoptions ,add-quoted:,prune:,prefix:,dont-ignore-missing-files -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -q|--add-quoted)                
                                    if test -z "${DIRS_QUOTED}";
                                    then
                                      if test -n "${2}";
                                      then
                                        DIRS_QUOTED="'${2}'"
                                      fi
                                    else
                                      if test -n "${2}";
                                      then
                                        DIRS_QUOTED="${DIRS_QUOTED} '${2}'"
                                      fi
                                    fi
                                    
                                    shift 2;;
                                    
    -k|--prune)                     CUSTOMPRUNE="${2}";               shift 2;;
       --prefix)                    TYPEOFBACKUP="${2}";              shift 2;;
       --dont-ignore-missing-files) DONT_IGNORE_MISSING_FILES="yes";  shift 1;;
    *) break ;;
  esac
done

NAMEOFBACKUP="${2}"
DIRS="${3}"
DIRS_EXCLUDE="${4:-^$}"

if test -z "${NAMEOFBACKUP}";
then
  alert "Backup job name is not defined. Backup will not be created"
  exit 1
fi

if test -z "${DIRS}" -a -z "${DIRS_QUOTED}";
then
  alert "Files or directories for backup is not defined. Backup will not be created"
  exit 1
fi

if test -z "${TYPEOFBACKUP}";
then
  TYPEOFBACKUP="${TYPEOFBACKUP_DEFAULT}"
fi

REPOSITORY="${BORG_SERVER}:$(hostname)-${NAMEOFBACKUP}"

TEMPLOG="$( mktemp )"
TEMPLOGPRUNE="$( mktemp )"

if test "${NAMEOFBACKUP}" == "SYSTEM";
then
  00-scripts/create_package_list.sh
  if test "${?}" -ne 0;
  then
    alert "Cannot get list of system packages, SYSTEM backup is not complete"
  else
    DIRS="${DIRS},/tmp/packages"
  fi
fi

DIRS_EVOLVED="$( printf "%s" "${DIRS}" | tr ',' ' ' )"
DIRS_EXCLUDE_EVOLVED="$( printf "%s" "${DIRS_EXCLUDE}" | tr ',' '\|')"

printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
borg init -e none "${REPOSITORY}"

CREATE_COMMAND_LINE=\
"borg create --show-rc --stats \
'${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' \
${DIRS_EVOLVED} ${DIRS_QUOTED} \
--exclude 're:${DIRS_EXCLUDE_EVOLVED}'"

printf "%s\n" "Create backup archive:"
printf "%s\n" "${CREATE_COMMAND_LINE}"
printf "%s\n" "${CREATE_COMMAND_LINE}" | bash &> "${TEMPLOG}"

CREATE_EXIT="${?}"

# Print log to stdout for manual run and logger
cat "${TEMPLOG}"

if test "${DONT_IGNORE_MISSING_FILES}" != "yes" -a "${CREATE_EXIT}" -ne 0 -a "${CREATE_EXIT}" -ne 1;
then
  alert "borg create failed. Pruning of old archives skipped" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  unlink "${TEMPLOGPRUNE}"
  exit 2
fi

if test "${DONT_IGNORE_MISSING_FILES}" == "yes" -a "${CREATE_EXIT}" -ne 0;
then
  alert "borg create failed. Pruning of old archives skipped" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  unlink "${TEMPLOGPRUNE}"
  exit 2
fi

unlink "${TEMPLOG}"

# --keep-hourly=1 - if backup binlog - keep backups for every hour
# Don't use other --keep-* if you create binlog backup!
# Example: Binlogs per hour will be PRUNED if user --keep-daily=1

PRUNE_COMMAND_LINE=\
"borg prune --show-rc --list '${REPOSITORY}' \
${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}"

printf "%s\n" "Prune old backup archives:"
printf "%s\n" "${PRUNE_COMMAND_LINE}"
printf "%s\n" "${PRUNE_COMMAND_LINE}" | bash &> "${TEMPLOGPRUNE}"

PRUNE_EXIT="${?}"

# Print log to stdout for manual run and logger
cat "${TEMPLOGPRUNE}"

if test "${PRUNE_EXIT}" -ne 0;
then
  alert "borg prune failed" "$( tail -n 20 < "${TEMPLOGPRUNE}" )"
  unlink "${TEMPLOGPRUNE}"
  exit 2
fi

unlink "${TEMPLOGPRUNE}"

exit 0
