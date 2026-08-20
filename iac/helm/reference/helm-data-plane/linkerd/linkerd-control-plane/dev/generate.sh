#!/usr/bin/env bash
# Create a local trust anchor and issuer. Do not commit ca.key, issuer.key, or live certs.
# Preferred on an existing cluster: linkerd upgrade --identity
# This script is the step(1) path when bootstrapping a new trust root.
set -euo pipefail
step certificate create root.linkerd.cluster.local ca.crt ca.key --profile root-ca --no-password --insecure
step certificate create identity.linkerd.cluster.local issuer.crt issuer.key --profile intermediate-ca --not-after 87600h --no-password --insecure --ca ca.crt --ca-key ca.key
