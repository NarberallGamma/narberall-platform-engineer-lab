# Mesh and ESO install (Helm)

**Business first:** Istio and External Secrets are **installed from charts**, then the estate kit adds policies. Hub: [`../../`](../../).

This kit is the **install trees** I used when the platform repo still vendored Istio 1.30.3 (`base` + `istiod`) and ESO 2.9.0. The estate cluster kit has PeerAuthentication and egress CRs; it does not contain these upstream charts.

```text
helm-mesh-eso/
  README.md
  istio/
    README.md
    values.yaml                 # sanitized istiod overlay
    scripts/vendor_charts.sh
    charts/base/                # official istio/base 1.30.3
    charts/istiod/              # official istio/istiod 1.30.3
  external-secrets/
    README.md
    values.yaml                 # sanitized ESO overlay
    scripts/vendor_charts.sh
    charts/external-secrets/    # official 2.9.0 + bitwarden-sdk-server v0.6.0 (disabled)
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Istio `base` + `istiod` | CRDs and control plane I actually upgraded, not a "install Istio" wiki line |
| ESO 2.9.0 | Install tree the estate Vault wrap talks to. This overlay is one replica (`leaderElect: false`); Bitwarden subchart stays vendored and off |

Helmfile app stands (ships-api, ollama) are a later apps pass. This folder is cluster install only.

## Sanitize

Live mesh IDs, ingress hosts, and registry mirrors are placeholders. [`../../SANITIZE.md`](../../SANITIZE.md).

**Keywords:** Istio, istiod, External Secrets Operator, Helm
