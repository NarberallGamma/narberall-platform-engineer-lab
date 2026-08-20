# Istio install (base + istiod)

Official Istio Helm charts vendored in git: `charts/base` + `charts/istiod`. Mesh policies (STRICT mTLS, egress) live in [`../../helm-estate-cluster/`](../../helm-estate-cluster/), not here.

| Parameter | Value |
|-----------|-------|
| Version | 1.30.3 (`base` and `istiod`) |
| Namespace | `istio-system` |
| Values | `values.yaml` (istiod overlay) |
| Gateways | none in this release |
| Auto-inject | disabled globally; opt-in via namespace label |

Charts are copied from https://istio-release.storage.googleapis.com/charts so CI does not pull from the internet on deploy. Image hub stays the public Istio registry unless a private mirror is set (`example.registry/istio`). `meshID` was empty on this install.

## Layout

```
istio/
  README.md
  values.yaml              # sanitized istiod overlay
  scripts/vendor_charts.sh
  charts/base/             # official istio/base 1.30.3
  charts/istiod/           # official istio/istiod 1.30.3
```

## What is installed

- CRDs and cluster-scoped resources (`istio-base`)
- Control plane (`istiod`, 1 replica, reduced lab resources: 100m/256Mi request, 500m/512Mi limit, HPA off). Overlay keys sit at the chart **root** (`replicaCount`, `autoscaleEnabled`, `resources`). Nested `pilot.*` is ignored by Istio 1.30.3 istiod.

Not installed: ingress gateway, egress gateway, PeerAuthentication, VirtualService, namespace auto-labeling.

## Coexistence with ingress-nginx

A cluster `ingress-nginx` addon stays untouched. Sidecars are opt-in:

```bash
kubectl label namespace app istio-injection=enabled --overwrite
```

Remove the label to stop injecting new pods:

```bash
kubectl label namespace app istio-injection-
```

## Refresh vendored charts (version bump)

```bash
ISTIO_VERSION=1.30.3 bash istio/scripts/vendor_charts.sh
```

## Install

```bash
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install istio-base istio/charts/base -n istio-system --wait --timeout 5m
helm upgrade --install istiod istio/charts/istiod -n istio-system --values istio/values.yaml --wait --timeout 10m
```
