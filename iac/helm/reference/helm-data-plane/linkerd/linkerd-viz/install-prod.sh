#!/usr/bin/env bash
# Viz overlay uses placeholder hosts and CHANGE_ME for remote_write auth.
set -euo pipefail
helm install linkerd-viz . -f values-prod.yaml -n linkerd-viz --create-namespace
