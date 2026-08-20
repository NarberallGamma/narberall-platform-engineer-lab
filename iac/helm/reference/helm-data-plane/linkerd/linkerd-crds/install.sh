#!/usr/bin/env bash
set -euo pipefail
helm install linkerd-crds . -n linkerd --create-namespace -f values-prod.yaml
