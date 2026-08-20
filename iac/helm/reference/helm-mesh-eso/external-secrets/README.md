# External Secrets Operator install

Official ESO Helm chart vendored in git: `charts/external-secrets`. ClusterSecretStore and Vault Kubernetes auth live in the estate cluster kit, not in this folder.

| Parameter | Value |
|-----------|-------|
| Version | 2.9.0 (appVersion v2.9.0) |
| Namespace | `external-secrets` |
| Values | `values.yaml` (non-HA overlay) |
| HA | no (1 replica controller / webhook / certController) |
| Bitwarden subchart | present in the 2.9.0 tree, `enabled: false` |
| Vault host (placeholder) | `vault.example.com` via `global.hostAliases` -> `10.10.4.10` |

Charts are copied from https://charts.external-secrets.io so CI does not pull chart packages on deploy. Container image stays `ghcr.io/external-secrets/external-secrets` unless a private mirror is set (`example.registry/external-secrets/external-secrets`).

hostAliases keep a TLS hostname valid when cluster CoreDNS does not resolve the external Vault FQDN.

## Layout

```
external-secrets/
  README.md
  values.yaml
  scripts/vendor_charts.sh
  charts/external-secrets/                 # vendored upstream 2.9.0
  charts/external-secrets/charts/bitwarden-sdk-server/  # v0.6.0, unused
```

## What is installed

1. ESO operator (CRDs + controller + webhook + certController)

Not in this kit: namespace/SA raw YAML, ClusterSecretStore, demo ExternalSecret. Those belong with the estate Vault wrap.

## Refresh vendored chart

```bash
ESO_VERSION=2.9.0 bash external-secrets/scripts/vendor_charts.sh
```

## Install

```bash
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install external-secrets external-secrets/charts/external-secrets \
  -n external-secrets -f external-secrets/values.yaml --wait --timeout 10m
```
