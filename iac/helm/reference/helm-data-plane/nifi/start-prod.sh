#!/usr/bin/env bash
# Install or upgrade the chart. Namespace is a placeholder.
helm upgrade -i nifi -n platform . -f values-prod.yaml
