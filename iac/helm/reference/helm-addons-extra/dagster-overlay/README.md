# Dagster overlay (Helm)

**Business first:** the data orchestrator is an **overlay**, not a 160-file vendor dump. Hub: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I published Chart.yaml, five environment values files, and one custom template. The upstream Dagster chart 1.8.7 (`charts/dagster/`, 161 files, including PostgreSQL and user-deployments subcharts) stays out. `helm dependency build` against the official repo pin.

```text
dagster-overlay/
  .helm/
    Chart.yaml                         # dagster 1.8.7 + werf export-values
    values_dev.yaml
    values_dev-alt.yaml                # second cluster, queuedRunCoordinator on
    values_production.yaml
    values_production-alt.yaml
    values_production-aws.yaml         # nodeSelector + CIDR allow-list
    templates/
      certificate_and_dex.yaml         # cert-manager Certificate + DexAuthenticator
```

Render (after `helm dependency build` in `.helm/`):

```bash
export WERF_ENV=dev
werf render --dev --values=.helm/values_$WERF_ENV.yaml
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Overlay only | Values + one extra manifest. Vendor tree is a NOTES pin |
| Dex + cert-manager | Ingress auth-url to `dagster-dex-authenticator`, TLS from ClusterIssuer |
| Five values files | Dev / prod / AWS vs a second cluster (queue on, 18Gi PG) |
| AWS file | Dedicated node role for runs, office CIDR whitelist on ingress |
| User deployments | `enableSubchart: false`; code images live in other releases |

## Vendor chart (documented, not vendored)

| Chart | Pin | What I changed | In git |
|-------|-----|----------------|--------|
| dagster | 1.8.7 | workspace servers, Dex ingress, PG affinity, run launcher nodeSelector | overlay only |

## Sanitize

Web hosts are `*.example.com`. User-code image is `example.registry/platform/user-code:CHANGE_ME`. Ingress allow-list uses documentation CIDRs (`203.0.113.0/24`, `198.51.100.0/24`).

**Keywords:** Dagster, Helm overlay, cert-manager, Dex, PostgreSQL, werf
