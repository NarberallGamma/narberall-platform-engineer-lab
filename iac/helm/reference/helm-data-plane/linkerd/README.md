# Linkerd (Helm)

**Business first:** a shop-class estate can run Linkerd as the mesh without sharing the Istio kit. Parent kit: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Case 01 style shop load: [`../../../../../case-studies/01-ai-llm-platform.md`](../../../../../case-studies/01-ai-llm-platform.md).

This folder is the **install tree**: CRDs, control plane, and viz. Identity private keys and live trust anchors are not stored here.

```text
linkerd/
  start-linkerd-core.sh          # CLI path (crds + control plane)
  linkerd-crds/                  # chart 2025.8.3, Gateway API off in env overlays
  linkerd-control-plane/         # edge-25.8.3; identity via --set-file
    values-lab.example.yaml      # cluster DNS + registry placeholders
    {dev,preprod,prod}/          # generate.sh + *.example only
  linkerd-viz/                   # dashboard + Prometheus remote_write overlay
    values-lab.example.yaml
    values-prod.yaml             # hosts and passwords are placeholders
    values-dev.yaml
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `linkerd-crds` | Full CRD chart plus env overlays that set `installGatewayAPI: false` |
| `linkerd-control-plane` | Real Helm install (identity issuer, proxy injector, destination). HA values file is present |
| `linkerd-viz` | Observability extension with Prometheus remote_write into the platform scrape estate |
| Identity layout | Three env folders. Keys and live anchors stripped. Generation is documented |

Pin: **edge-25.8.3** / chart **2025.8.3**.

## Identity (keys and live anchors stay out)

Private keys (`ca.key`, `issuer.key`) and live trust anchors (`ca.crt`, `issuer.crt`) were excluded from this tree.

Generate new material before `helm install`:

```bash
linkerd upgrade --identity
```

Alternative bootstrap (step CLI), from an env folder such as `linkerd-control-plane/prod/`:

```bash
./generate.sh
```

`*.example` files document filenames only. They are not usable trust material. Generated `ca.key`, `issuer.key`, and live PEMs stay local and are gitignored.

Install scripts under `linkerd-control-plane/` expect local `ca.crt`, `issuer.crt`, and `issuer.key` after generation.

## Install order

1. `linkerd-crds` (`install.sh`, `-f values-prod.yaml`)
2. `linkerd-control-plane` (`install-prod.sh` after identity exists; optional `-f values-ha.yaml` and `-f values-lab.example.yaml`)
3. `linkerd-viz` (`install-prod.sh`)

CLI alternative for core only: `start-linkerd-core.sh`.

## Sanitize

| Kind | Placeholder |
|------|-------------|
| Cluster DNS / trust domain | `cluster.local` in `values-lab.example.yaml` |
| Image registry | `example.registry/linkerd` (Prometheus image registry: `example.registry`) |
| Viz remote_write host | `prometheus.platform.example.com` / `prometheus.dev.platform.example.com` |
| Dashboard host regex | `linkerd-viz.platform.example.com` |
| Remote_write password | `CHANGE_ME` |

See [`../../../SANITIZE.md`](../../../SANITIZE.md).

**Keywords:** Linkerd, service mesh, identity issuer, linkerd-viz, Helm
