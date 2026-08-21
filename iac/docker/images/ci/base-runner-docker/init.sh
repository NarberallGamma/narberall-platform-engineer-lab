#!/bin/bash
set -e

# Docker login to the GitLab Container Registry.
# CI_REGISTRY, CI_REGISTRY_USER, CI_REGISTRY_PASSWORD: from the GitLab CI job payload.
# GITLAB_REGISTRY_SERVER, GITLAB_REGISTRY_USERNAME, GITLAB_REGISTRY_PASSWORD: from CI Variables when an explicit login is required.

# GitLab Registry (job payload)
if [[ -n "${CI_REGISTRY:-}" && -n "${CI_REGISTRY_USER:-}" && -n "${CI_REGISTRY_PASSWORD:-}" ]]; then
  echo "Logging in to GitLab registry $CI_REGISTRY..."
  echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"
  echo "GitLab registry login OK"
fi

# GitLab registry (explicit variables when CI_REGISTRY_* is not enough)
if [[ -n "${GITLAB_REGISTRY_SERVER:-}" && -n "${GITLAB_REGISTRY_USERNAME:-}" && -n "${GITLAB_REGISTRY_PASSWORD:-}" ]]; then
  echo "Logging in to GitLab registry $GITLAB_REGISTRY_SERVER..."
  echo "$GITLAB_REGISTRY_PASSWORD" | docker login -u "$GITLAB_REGISTRY_USERNAME" --password-stdin "$GITLAB_REGISTRY_SERVER"
  echo "GitLab registry $GITLAB_REGISTRY_SERVER login OK"
fi

echo "Registry logins done"
