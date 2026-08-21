#!/usr/bin/env bash

function auth_init {
  PROJECT_NAME=${1}
  AUTH_KEY_FILE=${2}
  SETUP_KEY="CHANGE_ME"
  test -f ${AUTH_KEY_FILE} && source ${AUTH_KEY_FILE}

  curl -s \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"type":"custom", "identifier":"borg_jobs_mon_v2", "use_default_team":true}' \
    https://alerts.example.com/api/${PROJECT_NAME}/self_setup/${SETUP_KEY} \
    | python -c "import sys, json; print('AUTH_KEY=' + json.load(sys.stdin)['auth_key'])" > ${AUTH_KEY_FILE}

}

function alert_log {
  ALERTS_LOG=/var/log/alerts.log
  echo "---" >> ${ALERTS_LOG}
  date +%Y.%m.%d" "%H:%M:%S >> ${ALERTS_LOG}
  echo "$1 $2 $3 $4 $5 $6" >> ${ALERTS_LOG}
  echo "$7" >> ${ALERTS_LOG}
  echo -e "$8" >> ${ALERTS_LOG}
}

get_first_line()
{
  printf "%s" "${1}" | head -n 1
}

escape_chars()
{
  printf "%s" "${1}" | sed --quiet "s/\\\/\\\\\\\/g;s/\r/\\\r/g;s/\t/\\\t/g;s/\"/\\\\\"/g;p"
}

escape_new_line()
{
  printf "%s" "${1}" | perl -pe 's/\n/\\n/g'
}

function simple_alert {
  PROJECT_NAME=${1:-"Empty project name!"}
  IMPACT=${2:-"Empty impact!"}
  LIKELIHOOD=${3:-"Empty likelihood!"}
  TRIGGER=${4:-"Empty trigger!"}
  SOURCE_SERVER=${5:-"Empty source server!"}
  TOTAL_ERRORS=${6:-"Empty total errors!"}
  SUMMARY=${7:-"Empty summary!"}
  CHECK_TYPE="${8}"
  DESCRIPTION=${9}
  AUTH_KEY_FILE="/var/cache/alerts_auth_key_${PROJECT_NAME}"

  alert_log "${PROJECT_NAME}" "${IMPACT}" "${LIKELIHOOD}" "${TRIGGER}" "${SOURCE_SERVER}" "${TOTAL_ERRORS}" "${SUMMARY}" "${DESCRIPTION}"

  auth_init ${PROJECT_NAME} ${AUTH_KEY_FILE}
  source ${AUTH_KEY_FILE}

  SUMMARY="$( get_first_line "$SUMMARY" )"
  SUMMARY="$( escape_chars "${SUMMARY}" )"
  SUMMARY="$( escape_new_line "${SUMMARY}" )"
  DESCRIPTION="$( escape_chars "${DESCRIPTION}" )"
  DESCRIPTION="$( escape_new_line "${DESCRIPTION}" )"
  CHECK_TYPE="$( escape_chars "${CHECK_TYPE}" )"

REQUEST_LOG="$(
  curl -vs \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{
          \"labels\": {
            \"impact\": \"${IMPACT}\",
            \"likelihood\": \"${LIKELIHOOD}\",
            \"trigger\": \"${TRIGGER}\",
            \"source_server\": \"${SOURCE_SERVER}\",
            \"check_type\": \"${CHECK_TYPE:-not-known}\"
          },
          \"annotations\": {
            \"summary\": \"${SUMMARY}\",
            \"description\": \"${DESCRIPTION}\",
            \"markup_format\": \"markdown\"
          },
          \"starts_at\": \"$( date +"%Y-%m-%d %H:%M:%S %z" )\"
        }" \
     https://alerts.example.com/api/events/custom/${AUTH_KEY}
)"

curl_exit_value=${?}

alert_answer=""
alert_answer="$( printf "%s" "${REQUEST_LOG}" | sed --quiet "/^ *{ *\"message\" *: *\"Ok\" *}/I{;p}" )"

if test "${curl_exit_value}" -ne 0 -o -z "${alert_answer}";
then
  return 1
fi

return 0
}
