# MinIO Operator

**Business first:** object storage on Kubernetes is an **operator and a Tenant CR**, not a Deployment with a PVC. Hub: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I stood up MinIO Operator 7.1.1 with the console subchart (console image v0.30.0). This slice **is** the install tree. A thinner MinIO contrast lives in the data-plane kit (DEV autostand).

```text
minio-operator/
  Chart.yaml                 # umbrella: operator 7.1.1 + console 0.1.0 (file://)
  Chart.lock
  values.yaml                # STS on, podAntiAffinity, console ingress off
  werf.yaml                  # image pins: operator v7.1.1, console v0.30.0
  crds/minio.min.io_tenants.yaml
  templates/                 # NOTES + helpers
  charts/
    operator/                # vendored operator 7.1.1 (CRDs, RBAC, STS)
    console/                 # vendored console UI
```

Tenant CRD pin (as used): `RELEASE.2025-06-13T11-33-47Z`. Operator docs: https://min.io/docs/minio/kubernetes/upstream/operations/install-deploy-manage/deploy-operator-helm.html

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Full operator tree | Hiring should parse the install I actually ran, not a marketplace one-liner |
| Console subchart | UI is a dependency with ingress off by default |
| STS | `OPERATOR_STS_ENABLED=on` plus the STS PolicyBinding CRD |
| Placement | Required podAntiAffinity on `kubernetes.io/hostname` |
| Values | Resource requests 200m/256Mi, non-root, dropped capabilities |

## Vendor chart (this slice keeps the tree)

| Chart | Pin | What I changed | In git |
|-------|-----|----------------|--------|
| minio-operator (umbrella) | 0.1.0 wrapping operator 7.1.1 | Console ingress host placeholder, STS on | full tree |
| operator | 7.1.1 from operator.min.io | values only | vendored templates + CRD |
| console | 0.1.0 / app v0.30.0 | ingress host `console.example.com`, enabled | vendored templates |

## Sanitize

Console host is `console.example.com`. No tenant credentials, no PEM, no secret-values. Image tags stay on `quay.io/minio/*`.

**Keywords:** MinIO, operator, Tenant CRD, STS, Helm, werf
