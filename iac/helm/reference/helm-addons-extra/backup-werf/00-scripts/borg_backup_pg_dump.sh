#!/usr/bin/env bash

# This script is a fallback PostgreSQL backup method

# Can be used when (all conditions must hold):
#   1. PostgreSQL version >= 8.3

# Restore from a pg_dump backup takes significantly longer than pg_basebackup
# and on large datasets (~300 GB) may take a full day

# How it works:
#   - if a single database is backed up or --one-archive is not set:
#     - invoke pg_dump and stream the dump to stdout
#     - back up the dump with borg, reading the dump from stdin
#   - otherwise:
#     - create and store database dumps under ${TMP_DIR} with pg_dump
#     - back up ${TMP_DIR} with borg_backup_files.sh

# Supported options:
# -h|--host                - PostgreSQL connect address. Optional argument
# -r|--port                - PostgreSQL connect port. Optional argument
# -u|--user                - username used to connect to PostgreSQL or to
#                            run pg_dump. Optional argument; if omitted,
#                            the value of ${USER_DEFAULT} is used
# -p|--password            - path to the password file used to connect to
#                            PostgreSQL, or the name of an environment
#                            variable that holds the password. Optional argument
# -d|--db                  - database name to back up; may be given several
#                            times; all listed databases are included. If several
#                            databases are listed, each goes into a separate
#                            Borg repository whose name includes the job name
#                            and the database name, i.e. $(hostname)-${db}-${NAMEOFBACKUP}
#                            instead of $(hostname)-${NAMEOFBACKUP}. All database
#                            backups can be placed in one archive with --one-archive.
#                            At least one database or --all-db is required
#    --all-db              - back up all databases served by the current
#                            PostgreSQL instance. The database list is taken from
#                            PostgreSQL and then the same algorithm as for a
#                            manual -d|--db list is used, i.e. a separate Borg
#                            repository is created per database. See
#                            -d|--db and --one-archive
# -e|--exclude-db          - database name to exclude from the backup; may be
#                            given several times; all listed databases are excluded
# -a|--add-pg_dump-option  - extra option passed to pg_dump. If the pg_dump
#                            option has a value, pass it with an equals sign ( = )
#                            (long options only) or a space; in the space form,
#                            quote the option and its value in double or single
#                            quotes. Examples:
#                             - --add-pg_dump-option --jobs=4
#                             - --add-pg_dump-option '--jobs 4'
#                             - --add-pg_dump-option "--jobs 4"
#                            The option may be given several times; all listed
#                            options are passed to pg_dump. Optional argument
# -k|--prune               - retention algorithm options string in
#                            Borg format, for example '--keep-hourly 72 --keep-within=30d'
#                            Optional argument; if omitted,
#                            the value of ${CUSTOMPRUNE_DEFAULT} is used
#    --do-su-under-user    - run pg_dump as the user from -u|--user or the
#                            default user. Useful when pg_hba.conf must use the
#                            'peer' authentication method instead of 'trust'
#    --one-archive         - store backups of different databases in one archive
#                            by writing them to a temporary directory. The
#                            filesystem must have enough free space to hold them.
#                            If the database list has only one database, the
#                            temporary directory is not used
#    --tmp-dir             - path to the temporary directory where database
#                            backups are stored. Optional argument; if omitted,
#                            the value of ${TMP_DIR_DEFAULT} is used

# Positional arguments:
# ${1} - job name, Borg repository name suffix; if omitted,
#        the name set in ${NAMEOFBACKUP_DEFAULT} is used

# The [-p, --password] option must not be given
# the password itself. Its value must be:
#   - a path to a password file. The file owner must be 'root:root' and
#     its mode must be '0400'
#   - the name of an environment variable that holds the password

# Usage example in schedule:
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh '--db db1'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --db db1 --db db2'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --db db1 --db db2 --user postgres'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --db db1 --db db2 --user postgres --do-su-under-user'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --db db1 --db db2 --user postgres --do-su-under-user -a "--table main" -a --blobs'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --db db1 --db db2 --user postgres --do-su-under-user -a "--table main" -a --blobs --prune "--keep-hourly 3 --keep-within=30d"'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --db db1 --db db2 --host 127.0.0.1 --user pg_super --password "/etc/backup/pg-pass"'
# borg_run_on.sh 10.0.0.1 borg_backup_pg_dump.sh 'PGDUMP --all-db --exclude-db "postgres" --user postgres --do-su-under-user'

################################################################################

source vars

NAMEOFBACKUP_DEFAULT='PGDUMP'
TYPEOFBACKUP='PGDUMP'
USER_DEFAULT="postgres"
DEFAULT_DATABASE="postgres"
CUSTOMPRUNE_DEFAULT='--keep-hourly=1 --keep-within=65d'
TMP_DIR_DEFAULT="/tmp/pg_dump"

export BORG_RSH="ssh -o ControlPath=none -o ControlMaster=no"

DESIRED_OPTIONS="
'--format=c'
'--compress=0'
"

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

add_trailing_single_quotes()
{
  printf "%s" "${1}" | sed --quiet "s/^/'/;s/$/'/;p"
}

get_env_var_value()
{
  if test -n "${1}";
  then
    printenv | grep --fixed-regexp "${1}=" | sed --quiet "s/[^=]*=//;s/^[ \t][ \t]*//;s/[ \t][ \t]*$//;s/\r//g;p"
  fi
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

################################################################################

NAMEOFBACKUP=""
HOST=""
PORT=""
USER=""
PASSWORD=""
DBS=""
DBS_COUNT=""
ALL_DB=""
DBS_EXCLUDE=""
ADDITIONAL_OPTIONS=""
CUSTOMPRUNE=""
DO_SU_UNDER_USER=""
ONE_ARCHIVE=""
TMP_DIR=""

PASSWORD_EVOLVED=""
REPOSITORY=""
EFFECTIVE_OPTIONS=""
PSQL_OPTIONS=""

# Command-line argument parsing
NORMALIZED_ARGS="$( getopt --options h:r:u:p:d:e:a:k: --longoptions ,host:,port:,user:,password:,db:,all-db,exclude-db:,add-pg_dump-option:,prune:,do-su-under-user,one-archive,tmp-dir: -- "${@}" 2>/dev/null )"
if test "${?}" -ne 0;
then
  alert "Unknown arguments found. Backup will not be created"
  exit 1
fi

eval set -- "${NORMALIZED_ARGS}"

while true
do
  case "${1}" in
    -h|--host)                HOST="${2}";         shift 2;;
    -r|--port)                PORT="${2}";         shift 2;;
    -u|--user)                USER="${2}";         shift 2;;
    -p|--password)            PASSWORD="${2}";     shift 2;;
    -d|--db)                  
                              if test -z "${DBS}";
                              then
                                DBS="'${2}'"
                              else
                                DBS="${DBS}"$'\n'"'${2}'"
                              fi
                              
                              shift 2;;
                              
       --all-db)              ALL_DB="yes";        shift 1;;
                              
    -e|--exclude-db)          
                              if test -z "${DBS_EXCLUDE}";
                              then
                                DBS_EXCLUDE="'${2}'"
                              else
                                DBS_EXCLUDE="${DBS_EXCLUDE}"$'\n'"'${2}'"
                              fi
                              
                              shift 2;;
                              
    -a|--add-pg_dump-option)  
                              if test -z "${ADDITIONAL_OPTIONS}";
                              then
                                ADDITIONAL_OPTIONS="'${2}'"
                              else
                                ADDITIONAL_OPTIONS="${ADDITIONAL_OPTIONS}"$'\n'"'${2}'"
                              fi
                              
                              shift 2;;
                              
    -k|--prune)               CUSTOMPRUNE="${2}";     shift 2;;
       --do-su-under-user)    DO_SU_UNDER_USER="yes"; shift 1;;
       --one-archive)         ONE_ARCHIVE="yes";      shift 1;;
       --tmp-dir)             TMP_DIR="${2}";         shift 2;;
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
  PSQL_OPTIONS="${PSQL_OPTIONS} --host '${HOST}'"
fi

if test -n "${PORT}";
then
  EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --port='${PORT}'"
  PSQL_OPTIONS="${PSQL_OPTIONS} --port '${PORT}'"
fi

if test -z "${USER}";
then
  printf "%s\n" "WARNING: user name is not defined, used default value '${USER_DEFAULT}'"
  USER="${USER_DEFAULT}"
fi

EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} --username='${USER}'"
PSQL_OPTIONS="${PSQL_OPTIONS} --username '${USER}'"

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
  PSQL_OPTIONS="${PSQL_OPTIONS} --password"
fi

for option in ${DESIRED_OPTIONS};
do
  if test "${option}" != "''";
  then
    EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
  fi
done

for option in ${ADDITIONAL_OPTIONS};
do
  if test "${option}" != "''";
  then
    EFFECTIVE_OPTIONS="${EFFECTIVE_OPTIONS} $( trim_trailing_single_quotes "${option}" )"
  fi
done

if test "${ALL_DB}" == "yes";
then
  if test -n "${DBS}";
  then
    printf "%s\n" "WARNING: options '-d|--db' and '--all-db' specified at the same time. Preference will be given to the option '--all-db'"
  fi
  
  PSQL_COMMAND_LINE="psql ${PSQL_OPTIONS} --no-align --tuples-only --command 'SELECT datname FROM pg_database WHERE datistemplate = false;' '${DEFAULT_DATABASE}'"
  
  if test -z "${PASSWORD_EVOLVED}";
  then
    if test "${DO_SU_UNDER_USER}" == "yes";
    then
      DBS="$( add_trailing_single_quotes "$( su - "${USER}" -c "${PSQL_COMMAND_LINE}" )" )"
    else
      DBS="$( add_trailing_single_quotes "$( bash -c "${PSQL_COMMAND_LINE}" )" )"
    fi
  else
    if test "${DO_SU_UNDER_USER}" == "yes";
    then
      DBS="$( add_trailing_single_quotes "$( printf "%s" "${PASSWORD_EVOLVED}" | su - "${USER}" -c "${PSQL_COMMAND_LINE}" )" )"
    else
      DBS="$( add_trailing_single_quotes "$( printf "%s" "${PASSWORD_EVOLVED}" | bash -c "${PSQL_COMMAND_LINE}" )" )"
    fi
  fi
fi

DBS="$( printf "%s" "${DBS}" | sort | uniq )"

for db_exclude in ${DBS_EXCLUDE};
do
  DBS="$( printf "%s" "${DBS}" | grep --fixed-regexp --invert-match "${db_exclude}" )"
done

DBS_COUNT="$( printf "%s" "${DBS}" | grep ".*" --count )"

if test "${DBS_COUNT}" -lt 1;
then
  alert "Databases list is empty - nothing to backup. Backup will not be created"
  exit 1
fi

if test "${ONE_ARCHIVE}" == "yes" -a "${DBS_COUNT}" -gt 1;
then
  printf "%s\n" "Is used the mode of saving databases copies in the temporary directory"
  
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
  
  printf "%s\n" "Create backup in temporary directory:"
  
  let backup_errors_count=0
  current_error=""
  errors_list=""
  
  for db in ${DBS};
  do
    PG_DUMP_COMMAND_LINE="pg_dump ${EFFECTIVE_OPTIONS} --file='${TMP_DIR}/$( trim_trailing_single_quotes "${db}" )' ${db}"
    
    if test -z "${PASSWORD_EVOLVED}";
    then
      if test "${DO_SU_UNDER_USER}" == "yes";
      then
        printf "%s\n" "su - \"${USER}\" -c \"${PG_DUMP_COMMAND_LINE}\""
        su - "${USER}" -c "${PG_DUMP_COMMAND_LINE}"
        PG_DUMP_EXIT="${?}"
      else
        printf "%s\n" "${PG_DUMP_COMMAND_LINE}"
        bash -c "${PG_DUMP_COMMAND_LINE}"
        PG_DUMP_EXIT="${?}"
      fi
    else
      if test "${DO_SU_UNDER_USER}" == "yes";
      then
        printf "%s\n" "su - \"${USER}\" -c \"${PG_DUMP_COMMAND_LINE}\""
        printf "%s" "${PASSWORD_EVOLVED}" | su - "${USER}" -c "${PG_DUMP_COMMAND_LINE}"
        PG_DUMP_EXIT="${?}"
      else
        printf "%s\n" "${PG_DUMP_COMMAND_LINE}"
        printf "%s" "${PASSWORD_EVOLVED}" | bash -c "${PG_DUMP_COMMAND_LINE}"
        PG_DUMP_EXIT="${?}"
      fi
    fi
    
    if test "${PG_DUMP_EXIT}" -ne 0;
    then
      current_error="pg_dump failed for database ${db}"
      
      if test -z "${errors_list}";
      then
        errors_list="${current_error}"
      else
        errors_list="${errors_list}"$'\n'"${current_error}"
      fi
      
      let backup_errors_count+=1
      continue
    fi
  done
  
  if test "${backup_errors_count}" -eq "${DBS_COUNT}";
  then
    alert "Errors found during backup, see description for view error list. Backup will not be created" "${errors_list}"
    rm -rf "${TMP_DIR}"
    exit 1
  fi
  
  if test "${backup_errors_count}" -ne 0;
  then
    alert "Errors found during backup, see description for view error list. An incomplete backup will be created" "${errors_list}"
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
  
  if test "${backup_errors_count}" -ne 0;
  then
    exit 1
  fi
else
  printf "%s\n" "Is used the pipe-mode"
  
  let backup_errors_count=0
  current_error=""
  errors_list=""
  
  for db in ${DBS};
  do
    if test "${DBS_COUNT}" -gt 1;
    then
      REPOSITORY="${BORG_SERVER}:$(hostname)-$( trim_trailing_single_quotes "${db}" )-${NAMEOFBACKUP}"
    else
      REPOSITORY="${BORG_SERVER}:$(hostname)-${NAMEOFBACKUP}"
    fi
    
    printf "%s\n" "Initialize backup repository '${REPOSITORY}':"
    borg init -e none "${REPOSITORY}"
    
    PG_DUMP_COMMAND_LINE="pg_dump ${EFFECTIVE_OPTIONS} ${db}"
    
    BORG_COMMAND_LINE="borg create --show-rc --stats '${REPOSITORY}::${TYPEOFBACKUP}-{now:%Y-%m-%d_%H:%M:%S}' -"
    
    printf "%s\n" "Create backup archive:"
    
    if test -z "${PASSWORD_EVOLVED}";
    then
      if test "${DO_SU_UNDER_USER}" == "yes";
      then
        printf "%s\n" "su - \"${USER}\" -c \"${PG_DUMP_COMMAND_LINE}\" | ${BORG_COMMAND_LINE}"
        su - "${USER}" -c "${PG_DUMP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
      else
        printf "%s\n" "${PG_DUMP_COMMAND_LINE} | ${BORG_COMMAND_LINE}"
        bash -c "${PG_DUMP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
      fi
      
      CREATE_EXIT=( "${PIPESTATUS[@]}" )
      
      if test "${CREATE_EXIT[0]}" -ne 0;
      then
        current_error="pg_dump failed for database ${db}, exit code ${CREATE_EXIT[0]}. Pruning of old archives skipped"
        
        if test -z "${errors_list}";
        then
          errors_list="${current_error}"
        else
          errors_list="${errors_list}"$'\n'"${current_error}"
        fi
        
        let backup_errors_count+=1
        continue
      fi
      
      if test "${CREATE_EXIT[1]}" -ne 0;
      then
        current_error="borg create failed for database ${db}, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped"
        
        if test -z "${errors_list}";
        then
          errors_list="${current_error}"
        else
          errors_list="${errors_list}"$'\n'"${current_error}"
        fi
        
        let backup_errors_count+=1
        continue
      fi
    else
      if test "${DO_SU_UNDER_USER}" == "yes";
      then
        printf "%s\n" "su - \"${USER}\" -c \"${PG_DUMP_COMMAND_LINE}\" | ${BORG_COMMAND_LINE}"
        printf "%s" "${PASSWORD_EVOLVED}" | su - "${USER}" -c "${PG_DUMP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
      else
        printf "%s\n" "${PG_DUMP_COMMAND_LINE} | ${BORG_COMMAND_LINE}"
        printf "%s" "${PASSWORD_EVOLVED}" | bash -c "${PG_DUMP_COMMAND_LINE}" | bash -c "${BORG_COMMAND_LINE}"
      fi
      
      CREATE_EXIT=( "${PIPESTATUS[@]}" )
      
      if test "${CREATE_EXIT[1]}" -ne 0;
      then
        current_error="pg_dump failed for database ${db}, exit code ${CREATE_EXIT[1]}. Pruning of old archives skipped"
        
        if test -z "${errors_list}";
        then
          errors_list="${current_error}"
        else
          errors_list="${errors_list}"$'\n'"${current_error}"
        fi
        
        let backup_errors_count+=1
        continue
      fi
      
      if test "${CREATE_EXIT[2]}" -ne 0;
      then
        current_error="borg create failed for database ${db}, exit code ${CREATE_EXIT[2]}. Pruning of old archives skipped"
        
        if test -z "${errors_list}";
        then
          errors_list="${current_error}"
        else
          errors_list="${errors_list}"$'\n'"${current_error}"
        fi
        
        let backup_errors_count+=1
        continue
      fi
    fi
    
    PRUNE_COMMAND_LINE="borg prune --show-rc --list '${REPOSITORY}' ${CUSTOMPRUNE:-${CUSTOMPRUNE_DEFAULT}}"
    
    printf "%s\n" "Prune old backup archives:"
    printf "%s\n" "${PRUNE_COMMAND_LINE}"
    printf "%s\n" "${PRUNE_COMMAND_LINE}" | bash
    
    PRUNE_EXIT="${?}"
    
    if test "${PRUNE_EXIT}" -ne 0;
    then
      current_error="borg prune failed for database ${db}, exit code ${PRUNE_EXIT}"
      
      if test -z "${errors_list}";
      then
        errors_list="${current_error}"
      else
        errors_list="${errors_list}"$'\n'"${current_error}"
      fi
      
      let backup_errors_count+=1
      continue
    fi
  done
  
  if test "${backup_errors_count}" -eq "${DBS_COUNT}";
  then
    alert "Errors found during backup, see description for view error list. Backup will not be created or be empty" "${errors_list}"
    exit 1
  fi
  
  if test "${backup_errors_count}" -ne 0;
  then
    alert "Errors found during backup, see description for view error list. An incomplete backup will be created" "${errors_list}"
    exit 1
  fi
fi

exit 0
