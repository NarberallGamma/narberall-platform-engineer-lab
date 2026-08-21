#!/usr/bin/env bash

case "$1" in
  admin)
    gunicorn admin_api.wsgi:app --bind=0.0.0.0:5000 --bind=[::1]:5000 --workers=1 --threads=4 --max-requests=1000
#    waitress-serve --listen=0.0.0.0:5000 --threads=5 admin_api.wsgi:app
    ;;
  admin-celery)
    celery "${@:2}"
    ;;
  admin-flask)
    flask "${@:2}"
    ;;
  consume-events)
    FLASK_APP=admin_api/app.py flask consume-events
    ;;
  *)
    # The command is something like bash, not an admin subcommand. Run it in the same environment.
    echo "$@"
    ;;
esac
