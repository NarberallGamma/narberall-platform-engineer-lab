#!/usr/bin/env bash

# Wrapper around simple_alert.sh for custom alert events.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $DIR/simple_alert.sh
ALERT_LOG=/var/log/alerts-timeout.log

PROJECT_NAME=${1:-"Empty project name!"}
IMPACT=${2:-"Empty impact!"}
LIKELIHOOD=${3:-"Empty likelihood!"}
TRIGGER=${4:-"Empty trigger!"}
SOURCE_SERVER="${HOSTNAME}"
TOTAL_ERRORS="1"
SUMMARY=${5:-"Empty summary!"}
CHECK_TYPE="${6}"
DESCRIPTION=${7}


# trigger summary description
simple_alert "${PROJECT_NAME}" "${IMPACT}" "${LIKELIHOOD}" "${TRIGGER}" "${SOURCE_SERVER}" "${TOTAL_ERRORS}" "${SUMMARY}" "${CHECK_TYPE}" "${DESCRIPTION}"

if test ${?} -ne 0;
then
  echo "---------------\n `date` \n \n ---" >> $ALERT_LOG ;
  echo "simple_alert ${PROJECT_NAME} ${IMPACT} ${LIKELIHOOD} ${TRIGGER} ${SOURCE_SERVER} ${TOTAL_ERRORS} ${SUMMARY}\n" >> $ALERT_LOG ;
  echo -e "${DESCRIPTION}" >> $ALERT_LOG ;
  echo "\n\n" >> $ALERT_LOG ;
  exit 1
fi

exit 0
