#!/bin/bash
set -e

# Fail when KUBE_SERVER or KUBE_TOKEN is unset.
if [ -z "$KUBE_SERVER" ] || [ -z "$KUBE_TOKEN" ]; then
    echo "Error: KUBE_SERVER and KUBE_TOKEN must be set"
    exit 1
fi

# Write kubeconfig from the CI token payload.
cat > ~/.kube/config << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: $KUBE_SERVER
    insecure-skip-tls-verify: true
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
users:
- name: default
  user:
    token: $KUBE_TOKEN
EOF

echo "Kubeconfig configured successfully"
