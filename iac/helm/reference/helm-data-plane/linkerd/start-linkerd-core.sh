#!/usr/bin/env bash
# CLI path for CRDs + control plane. Helm identity files are not used here.
# For the Helm path, generate identity with: linkerd upgrade --identity
set -euo pipefail
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
