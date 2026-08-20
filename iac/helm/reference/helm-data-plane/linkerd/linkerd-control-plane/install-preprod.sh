#!/usr/bin/env bash
# Install after local identity files exist (see ../README.md).
# Generate with: linkerd upgrade --identity
# or: (cd preprod && ./generate.sh)
# Do not commit ca.key, issuer.key, or live trust anchors.
set -euo pipefail
helm install linkerd-control-plane . \
  -n linkerd \
  --set-file identityTrustAnchorsPEM=preprod/ca.crt \
  --set-file identity.issuer.tls.crtPEM=preprod/issuer.crt \
  --set-file identity.issuer.tls.keyPEM=preprod/issuer.key
