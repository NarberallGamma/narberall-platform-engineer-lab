#!/usr/bin/env bash

# Primary way to back up WAL file archives

# How it works:
#   - back up WAL file archives with borg_backup_files.sh
#   - delete old WAL file archives with find

# WAL archiving into a dedicated directory must be configured
# before WAL archive backups are set up.
# In postgresql.conf:
#   - enable WAL archiving by setting 'archive_mode' to 'on'
#   - set the WAL archive command in 'archive_command'
#   - restart the PostgreSQL service (after agreeing with the team or client)
# Typical 'archive_mode' and 'archive_command' values:
# archive_mode = on
# archive_command = '/usr/bin/test ! -f /var/backups/pgsql/wal/%f.tgz && /bin/tar -zcf /var/backups/pgsql/wal/%f.tgz %p'

# If the Borg backup repository grows too large and the
# deduplication ratio is no more than two, i.e. repository-wide
# 'Deduplicated size' is not at least 2x smaller than 'Original size',
# WAL archive compression may be disabled with an uncompressed 'archive_command':
# archive_command = '/usr/bin/test ! -f /var/backups/pgsql/wal/%f.tar && /bin/tar -cf /var/backups/pgsql/wal/%f.tar %p'
# archive_command may be changed only after agreeing with the team/client

# If WAL files are archived too rarely and some backups end up
# near-zero size, PostgreSQL can be told to archive WAL files after a
# timeout via archive_timeout. A good value is about 600 seconds.
# archive_timeout may be used only after agreeing with the team/client

# Supported options:
# -k|--prune      - retention options in Borg format, for
#                   example '--keep-hourly 72 --keep-within=30d'
#                   Optional; if omitted,
#                   ${CUSTOMPRUNE_DEFAULT} is used

# Positional arguments:
# ${1} - path to the WAL file archive directory. Required
# ${2} - maximum WAL file lifetime in days; WAL files older than
#        this are deleted. Because of rounding, actual lifetime
#        may be up to 1 day longer than the given maximum.
#        Optional; if omitted,
#        ${THRESHOLD_DEFAULT} is used

# Schedule usage examples:
# borg_run_on.sh 10.0.0.1 borg_backup_wals.sh '/var/backups/pgsql/wal'
# borg_run_on.sh 10.0.0.1 borg_backup_wals.sh '/var/backups/pgsql/wal 7'
# borg_run_on.sh 10.0.0.1 borg_backup_wals.sh '/var/backups/pgsql/wal 7 --prune "--keep-hourly 3 --keep-within=30d"'

# Using a WAL archive directory shallower than level 3, i.e. '/', '/etc',
# '/var', and similar, or any directory listed in ${PROTECTED_DIRS},
# aborts the script and produces no backups

################################################################################

NAMEOFBACKUP_DEFAULT='WAL'
THRESHOLD_DEFAULT='14'
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
  BACKUP_TYPE="${NAMEOFBACKUP:-${NAMEOFBACKUP_DEFAULT}}"
  MESSAGE="${1}"
  FULL_MESSAGE="${2}"
  
  printf "%s\n" "ERROR: ${MESSAGE}"
  printf "%s\n" "${FULL_MESSAGE}"
  backup_notify --trigger backup --label backup_target="${BACKUP_TARGET}" --label backup_type="${BACKUP_TYPE}" --summary "${MESSAGE}" "${FULL_MESSAGE}"
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

# Check that the input string is a positive number
#${1} - string
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

################################################################################

CUSTOMPRUNE=""

# Parse command-line arguments
NORMALIZED_ARGS="$( getopt --options k: --longoptions ,prune: -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -k|--prune)  CUSTOMPRUNE="${2}";  shift 2;;
    *) break ;;
  esac
done

NAMEOFBACKUP="${NAMEOFBACKUP_DEFAULT}"
WALDIR="${2}"
THRESHOLD="${3}"

IFS=$'\n'

if test -z "${WALDIR}";
then
  alert "WAL directory is not defined"
  exit 1
fi

if test ! -e "${WALDIR}";
then
  alert "WAL directory does not exists"
  exit 1
fi

if test ! -d "${WALDIR}";
then
  alert "Name of WAL directory in use but is not a directory"
  exit 1
fi

if test ! -r "${WALDIR}";
then
  alert "WAL directory does not readable by this user"
  exit 1
fi

if test ! -x "${WALDIR}";
then
  alert "WAL directory does not executable by this user"
  exit 1
fi

for dir in ${PROTECTED_DIRS};
do
if test "$( compare_vfs_paths "${WALDIR}" "${dir}" )" == "equal" -o "$( compare_vfs_paths "${WALDIR}" "${dir}" )" == "uncertain";
  then
    alert "Directory '${dir}' is protected and cannot be specified as the WAL directory."
    exit 1
  fi
done

if test "$( get_vfs_path_level "${WALDIR}" )" -le "2";
then
  alert "WAL directory level cannot be less that 2"
  exit 1
fi

check_to_positive_number_format "${THRESHOLD}"
if test "${?}" -ne 0;
then
  printf "%s\n" "WARNING: cleaning time threshold of WAL directory '${THRESHOLD}' is not numeric or less than 1. Used default value '${THRESHOLD_DEFAULT}' days"
  THRESHOLD="${THRESHOLD_DEFAULT}"
fi

printf "%s\n" "Backup WAL directory:"

00-scripts/borg_backup_files.sh "${NAMEOFBACKUP}" "${WALDIR}" --prune "${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}" --dont-ignore-missing-files
if test "${?}" -ne 0;
then
  alert "Cannot backup WAL directory '${WALDIR}'. Also the WAL directory will not be cleared"
  exit 1
fi

printf "%s\n" "Clean WAL directory:"

find "${WALDIR}" -mindepth 1 -mtime "+${THRESHOLD}" -print -delete
if test "${?}" -ne 0;
then
  alert "Cannot clean WAL directory '${WALDIR}'"
  exit 1
fi

exit 0
