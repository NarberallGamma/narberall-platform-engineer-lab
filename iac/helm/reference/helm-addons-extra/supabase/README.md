# Supabase (Helm overlay)

**Business first:** BaaS is a **chart with pinned images**, not a hosted click-through. Hub: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I stood up Supabase as a werf umbrella: vendor chart `supabase` 0.1.2, every component image exported from `werf.yaml` (`logflare`, `gotrue`, Studio, Postgres, Kong, Storage, imgproxy, Vector). Values turn the full stack on except MinIO. Ingress is Kong plus nginx, with RFC1918 whitelist and in-cluster TLS secret name.

The vendor tarball is not in git. `helm dependency build` against the Chart.lock pin.

```text
supabase/
  werf.yaml                 # one image stanza per Supabase component
  .gitlab-ci.yml            # werf lint + render + converge
  .helm/
    Chart.yaml              # export-values: werf.repo/tag -> vendor image fields
    Chart.lock              # supabase 0.1.2
    values.yaml
    secret-values.example.yaml
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `export-values` | Werf image tags land in the vendor chart without a fork |
| Values | Per-component resources, worker affinity, probes, 8Gi Postgres PVC |
| Kong ingress | Studio/API on one host, private CIDR allow-list |
| CI | `werf helm lint` then `werf render --validate` then converge |

## Vendor chart (documented, not vendored)

| Chart | Pin | What I changed | In git |
|-------|-----|----------------|--------|
| supabase (teochenglim) | 0.1.2 | image export-values, resources, ingress, MinIO off | Chart.yaml + values. `.tgz` stays out |

## Secrets

Copy `.helm/secret-values.example.yaml` to `.helm/secret-values.yaml`. `.gitignore` keeps `secret-values.yaml`, `.werf_secret_key`, and vendor `.tgz` out of git. JWT, DB, SMTP, and dashboard credentials stay out of git.

## Sanitize

Live studio URL, TLS secret host, and kube context names are placeholders (`supabase.example.com`, `wildcard.example.com`).

**Keywords:** Supabase, Kong, werf, Helm, BaaS, Postgres, GoTrue
