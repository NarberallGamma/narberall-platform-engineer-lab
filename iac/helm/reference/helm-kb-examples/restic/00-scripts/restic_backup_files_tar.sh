#!/usr/bin/env bash

# Fallback file backup method. Files are placed in a tar archive first.
# Needed so a restic backup can hold a variable file list without triggering monitoring.
# Useful, for example, for binlog files stored in a shared MySQL directory.

# How it works:
#   - create a file and/or directory backup in the restic repository with
#     'restic backup'
#   - delete old backups in the restic repository with 'restic forget --prune'

# Supported options:
# -q|--add-quoted                - path to a file or directory to
#                                  back up. The option may be repeated; the
#                                  backup will include all listed files and/or directories.
#                                  Listed paths are wrapped in single quotes — paths
#                                  with spaces are handled correctly, but wildcards
#                                  will not expand. Optional; file and/or directory
#                                  paths must be given either with
#                                  this option or with positional argument ${2};
#                                  they may also be used together
# -t|--tar-options               - tar options for building the archive. Optional.
# -k|--prune                     - retention-options string in
#                                  restic format, e.g. '--keep-hourly 72 --keep-within 30d'
#                                  Optional. When omitted,
#                                  ${CUSTOMPRUNE_DEFAULT} is used

# Positional arguments:
# ${1} - job name, restic repository tag. Required
# ${2} - comma-separated paths to files or directories to
#        back up. Wildcards are accepted; spaces in
#        paths are NOT handled correctly. Required when
#        -q|--add-quoted is unused, or exclusions must be given
#        from the backup via positional argument ${3}

# Schedule examples:
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_files.sh 'SYSTEM /etc,/var/spool/cron,/etc/backup-agent/config.d'
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_files.sh 'DATA /var'
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_files.sh 'DATA /var --tar-options "--exclude=temp-* --exclude=lost+found"'
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_files.sh 'DATA /var --tar-options "--exclude=temp-* --exclude=lost+found --warning=no-file-changed" --prune "--keep-hourly 3 --keep-within 30d"'
# restic_run_on.sh 10.0.0.1 <restic_bucket_from_values> restic_backup_files.sh 'LOGS /var/log/auth.log*,/var/log/wtmp* --add-quoted "/var/log/apt" --add-quoted "/var/log/cups"'
################################################################################

CUSTOMPRUNE_DEFAULT='--keep-hourly 1 --keep-within 65d'

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
TAR_OPTIONS=""
CUSTOMPRUNE=""

# Parse command-line arguments
NORMALIZED_ARGS="$( getopt --options q:t:k: --longoptions ,add-quoted:,tar-options:,prune:,prefix: -- "${@}" 2>/dev/null )"
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
    -t|--tar-options)               TAR_OPTIONS="${2}";               shift 2;;
    -k|--prune)                     CUSTOMPRUNE="${2}";               shift 2;;
    *) break ;;
  esac
done

NAMEOFBACKUP="${2}"
DIRS="${3}"

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

if test "${DO_NOT_USE_HOSTNAME_IN_RESTIC_REPO_NAME}" == "yes";
then
  RESTIC_HOSTNAME="${NAMEOFBACKUP}"
else
  RESTIC_HOSTNAME="$( hostname )"
fi

TEMPLOG="$( mktemp )"
TEMPLOGPRUNE="$( mktemp )"

DIRS_EVOLVED="$( printf "%s" "${DIRS}" | tr ',' ' ' )"

restic init || echo "skip initialization."

COMMAND_LINE=\
"tar ${TAR_OPTIONS} -cf - ${DIRS} 2>>$TEMPLOG"

RESTIC_COMMAND_LINE=\
"restic backup --verbose \
--tag ${NAMEOFBACKUP} \
--stdin --stdin-filename ${NAMEOFBACKUP}.tar"

printf "%s\n" "Create backup archive:"
printf "%s\n" "${COMMAND_LINE} | ${RESTIC_COMMAND_LINE}"
bash -c "${COMMAND_LINE}" | bash -c "${RESTIC_COMMAND_LINE}"

#CREATE_COMMAND_LINE=\
#"restic backup --verbose \
#--tag ${NAMEOFBACKUP} \
#${DIRS_EVOLVED} ${DIRS_QUOTED} \
#--exclude '${DIRS_EXCLUDE_EVOLVED}' \
#--hostname '${RESTIC_HOSTNAME}'"

#printf "%s\n" "Create backup archive:"
#printf "%s\n" "${CREATE_COMMAND_LINE}"
#printf "%s\n" "${CREATE_COMMAND_LINE}" | bash &> "${TEMPLOG}"

CREATE_EXIT=( "${PIPESTATUS[@]}" )

# Print log to stdout for manual run and logger
cat "${TEMPLOG}"

if test "${CREATE_EXIT[0]}" -ne 0 -a "${CREATE_EXIT[0]}" -ne 1;
then
  alert "tar exec failed, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  unlink "${TEMPLOGPRUNE}"
  exit 1
fi

if test "${CREATE_EXIT[1]}" -ne 0;
then
  alert "restic create failed, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped" "$( tail -n 20 < "${TEMPLOG}" )"
  unlink "${TEMPLOG}"
  unlink "${TEMPLOGPRUNE}"
  exit 1
fi

unlink "${TEMPLOG}"

# --keep-hourly=1 - if backup binlog - keep backups for every hour
# Don't use other --keep-* if you create binlog backup!
# Example: Binlogs per hour will be PRUNED if user --keep-daily=1

PRUNE_COMMAND_LINE=\
"restic forget --prune --tag '${NAMEOFBACKUP}' \
${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}"

printf "%s\n" "Prune old backup archives:"
printf "%s\n" "${PRUNE_COMMAND_LINE}"
printf "%s\n" "${PRUNE_COMMAND_LINE}" | bash &> "${TEMPLOGPRUNE}"

PRUNE_EXIT="${?}"

# Print log to stdout for manual run and logger
cat "${TEMPLOGPRUNE}"

if test "${PRUNE_EXIT}" -ne 0;
then
  alert "restic prune failed" "$( tail -n 20 < "${TEMPLOGPRUNE}" )"
  unlink "${TEMPLOGPRUNE}"
  exit 2
fi

unlink "${TEMPLOGPRUNE}"

exit 0
