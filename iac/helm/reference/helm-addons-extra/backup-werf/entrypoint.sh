#!/bin/bash

ENV=${1}
cp /app/vars-${ENV} /app/vars
cp /app/schedule-${ENV} /app/schedule

exec /usr/local/bin/supercronic -json /app/schedule
