#!/bin/bash

echo "Creating regcred secrets in target namespaces..."
echo "Target namespaces: $TARGET_NAMESPACES"

# Convert comma-separated namespaces to array
IFS=',' read -ra NAMESPACES <<< "$TARGET_NAMESPACES"

create_docker_registry_secret() {
  local secret_name="$1"
  local server="$2"
  local username="$3"
  local password="$4"
  local namespace="$5"

  if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
    echo "Secret $secret_name already exists in namespace $namespace, updating..."
    kubectl delete secret "$secret_name" -n "$namespace"
  fi

  kubectl create secret docker-registry "$secret_name" \
    --docker-server="$server" \
    --docker-username="$username" \
    --docker-password="$password" \
    --namespace="$namespace"

  echo "Created $secret_name secret in namespace: $namespace (server=$server)"
}

for ns in "${NAMESPACES[@]}"; do
  # Trim whitespace
  ns=$(echo "$ns" | xargs)

  echo "Processing namespace: $ns"

  # Check if namespace exists
  if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
    echo "Warning: Namespace $ns does not exist, skipping..."
    continue
  fi

  # legacy private registry
  create_docker_registry_secret "regcred" \
    "$REGISTRY_SERVER" \
    "$LEGACY_REGISTRY_USERNAME" \
    "$LEGACY_REGISTRY_PASSWORD" \
    "$ns"

  # external private registry
  if [[ -n "${EXTERNAL_REGISTRY_USERNAME:-}" && -n "${EXTERNAL_REGISTRY_PASSWORD:-}" ]]; then
    create_docker_registry_secret "external-regcred" \
      "$EXTERNAL_REGISTRY_SERVER" \
      "$EXTERNAL_REGISTRY_USERNAME" \
      "$EXTERNAL_REGISTRY_PASSWORD" \
      "$ns"
  else
    echo "External registry credentials not provided, skipping external-regcred secret"
  fi

  # GitLab registry (estate)
  if [[ -n "${GITLAB_REGISTRY_USERNAME:-}" && -n "${GITLAB_REGISTRY_PASSWORD:-}" ]]; then
    create_docker_registry_secret "gitlab-regcred" \
      "$GITLAB_REGISTRY_SERVER" \
      "$GITLAB_REGISTRY_USERNAME" \
      "$GITLAB_REGISTRY_PASSWORD" \
      "$ns"
  else
    echo "GitLab registry credentials not provided, skipping gitlab-regcred secret"
  fi
done

echo "All regcred secrets created successfully!"

# Show all regcred secrets
echo "Listing registry secrets:"
for ns in "${NAMESPACES[@]}"; do
  ns=$(echo "$ns" | xargs)
  if kubectl get namespace "$ns" >/dev/null 2>&1; then
    echo "Namespace: $ns"
    kubectl get secret regcred -n "$ns" 2>/dev/null || echo "  No regcred secret found"
    kubectl get secret external-regcred -n "$ns" 2>/dev/null || echo "  No external-regcred secret found"
    kubectl get secret gitlab-regcred -n "$ns" 2>/dev/null || echo "  No gitlab-regcred secret found"
  fi
done
