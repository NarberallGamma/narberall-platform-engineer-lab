# Werf monorepo sample

**Business first:** forty services share **one values file**, not forty Chart.yaml copies. Buyer page: [`../../../../docs/for-business.md`](../../../../docs/for-business.md). Case: [`../../../../case-studies/11-helm-estate.md`](../../../../case-studies/11-helm-estate.md).

I used a werf monorepo for a multi-service estate. Each unit is a folder with `werf.yaml` and `templates/`. There is no Chart.yaml. Shared values, lockbox helpers, and placement snippets live once under `common-templates`. CI points every release at that file (`WERF_VALUES_1` / `WERF_SECRET_VALUES_1`). This sample is the shared pack plus one cache-proxy unit.

Brand feed adapters stay out. Live FQDNs, CIDRs, registry hosts, and werf-encrypted secret bodies are stripped.

Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md). A thinner werf-raw tree (single app, `.helm/` without Chart.yaml) is a sibling sample under [`../`](../).

```text
werf-monorepo-sample/
  .gitignore
  .werf/
    common-templates/
      values.yaml                      # excerpt: envelope + s3_cache_proxy
      secret-values.example.yaml       # CHANGE_ME only; live file is gitignored
      _affinity_and_tolerations.tpl    # production nodeAffinity + tolerations
      _envoy.tpl                       # Gateway API HTTPRoute + optional JWT
      _lockbox.tpl                     # ExternalSecret (ClusterSecretStore)
      _lockbox_rds.tpl                 # ExternalSecret + RDS URL template
      _notes.tpl                       # release image summary
    s3-cache-proxy/
      werf.yaml                        # image: nginx-s3-gateway; helmChartDir from env
      templates/
        s3-cache-proxy-config.yaml     # lockbox Secret or inline env Secret
        s3-cache-proxy-deployment.yaml # Service + Deployment, Recreate
        NOTES.txt
        _affinity_and_tolerations.tpl  # symlink to common-templates
        _lockbox.tpl                   # symlink
        _notes.tpl                     # symlink
```

Render (from this directory, after copying the example secrets file):

```bash
cp .werf/common-templates/secret-values.example.yaml .werf/common-templates/secret-values.yaml
export RELEASE_NAME=s3-cache-proxy
export HELM_DIRECTORY=".werf/${RELEASE_NAME}"
werf render \
  --values=".werf/common-templates/values.yaml" \
  --secret-values=".werf/common-templates/secret-values.yaml" \
  --env dev \
  --dev
```

`helm template` alone is not the path. Werf sets `helmChartDir` from `HELM_DIRECTORY` and merges the shared values.

## Who this page is for

Hiring lead: this is the monorepo mechanic I actually ran, reduced to one unit. Engineer: there is no Chart.yaml on purpose.

## What this kit is / is not

It is shared values plus unit templates. It is not a Helm library chart, not an OCI `common` dependency, and not a 40-folder farm. Sibling units (admin UIs, history fetchers, brand market-data adapters) stay private.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| No Chart.yaml | Werf treats `.werf/<unit>` as the chart dir. The estate had ~12 template archetypes, not 40 unique charts |
| One values file | `pluck .Values.werf.env` with `_default`. Every unit is a top-level key. This excerpt keeps `s3_cache_proxy` and the envelope (`envoy_common`, `whitelist`, `clusterissuer`) |
| Symlinked helpers | Unit `templates/_*.tpl` point at `common-templates`. Placement, lockbox, and NOTES stay one edit |
| Lockbox vs inline | Production: ExternalSecret from ClusterSecretStore. Dev: Secret from merged values + secret-values |
| Cache proxy | nginx S3 gateway, `emptyDir` cache, Deckhouse secret-reload annotation, Recreate |
| Envoy helper | Gateway API HTTPRoute + optional JWT SecurityPolicy. This unit does not call it; the pack is shared |

## How the monorepo wires

1. Unit folder: `werf.yaml` (`project` + `deploy.helmChartDir`) and `templates/`.
2. Shared values: `--values .werf/common-templates/values.yaml` (CI: `WERF_VALUES_1`).
3. Shared secrets: `--secret-values .werf/common-templates/secret-values.yaml` (CI: `WERF_SECRET_VALUES_1`). Bodies stay out of git.
4. Helpers: relative symlinks from each unit into `common-templates`.
5. Env pluck: `production` gets lockbox + node affinity (`node-role.kubernetes.io/production` and `prod-nodes`). `dev` gets the inline Secret.

## Sanitize

Hosts are `*.example.com`. JWKS is `https://keycloak.example.com/realms/platform/...`. S3 endpoint is `s3.example.com`, bucket `history-cache`. Lockbox store is `platform-css`. Allow-list uses documentation CIDRs (`203.0.113.0/24`, `198.51.100.10/32`). Credentials are `CHANGE_ME` in the example file only.

**Keywords:** werf, monorepo, Helm, no Chart.yaml, ExternalSecret, nginx-s3-gateway, shared values, Gateway API
