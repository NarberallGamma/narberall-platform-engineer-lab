# SonarQube overlay (Helm)

**Business first:** the quality gate is a **chart I stood up**, not a SaaS checkbox. Hub: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

Werf umbrella over the SonarSource chart. I pin **2025.4.1** (enterprise), export image repo/tag from `werf.yaml` into the vendor fields, and point JDBC at an **external** Aurora-class Postgres (`postgresql.enabled: false`). The vendor `.tgz` is not in git.

```text
sonarqube/
  werf.yaml                 # images: sonarqube enterprise, busybox init
  .gitlab-ci.yml
  sonar-project.properties  # qualitygate.wait; fake projectKey
  .helm/
    Chart.yaml              # export-values: werf.repo/tag -> image + postgres/init
    Chart.lock              # sonarqube 2025.4.1
    requirements.lock       # older 10.6 pin left as history
    values.yaml             # StatefulSet, ingress, probes, securityContext
```

`helm dependency build` against Chart.lock. Then werf converge.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Overlay only | Chart.yaml + values. Upstream chart stays a pin |
| `export-values` | Werf image tags land in vendor `image` / `init` / `postgresql.image` |
| External DB | `jdbcOverwrite` to RDS-shaped host; in-cluster Postgres off |
| Hardening | drop ALL caps, non-root, seccomp RuntimeDefault, gp3 20Gi |
| Probes | startup 24 failures / 10s; readiness and liveness 60s delay |
| Ingress | TLS secret name is a placeholder (`example-com-wildcard-tls`) |

## Vendor chart (documented, not vendored)

| Chart | Pin | What I changed | In git |
|-------|-----|----------------|--------|
| sonarqube (SonarSource) | 2025.4.1 | export-values, enterprise, external JDBC, securityContext, gp3 | Chart.yaml + values. `.tgz` stays out |

## Sanitize

Ingress host `sonarqube.example.com`. JDBC URL uses `sonarqube.cluster-example.us-east-2.rds.amazonaws.com`. JDBC password is not in git.

**Keywords:** SonarQube, Helm overlay, werf, Aurora, PostgreSQL, quality gate
