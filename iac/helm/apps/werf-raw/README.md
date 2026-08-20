# Werf-raw apps (no Chart.yaml)

**Business first:** some product apps ship as **werf plus `.helm/`**, not a Chart.yaml farm. Buyer page: [`../../../../docs/for-business.md`](../../../../docs/for-business.md). Case: [`../../../../case-studies/11-helm-estate.md`](../../../../case-studies/11-helm-estate.md). Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

I publish two trees. Neither has Chart.yaml. Werf treats `.helm/` as the chart and fills `.Chart.Name` from `project:` in `werf.yaml`.

```text
werf-raw/
  webapps/      # PHP-FPM + nginx, queue worker, two supercronic crons
  dashboard/    # SPA build artifact, nginx, Dex on non-prod, object-storage upload
```

A richer Borg backup that is also werf-raw (no Chart.yaml) already lives in [`../../reference/helm-addons-extra/backup-werf/`](../../reference/helm-addons-extra/backup-werf/). This folder is the **application** form of the same packaging.

## What hiring should see

| Tree | Why it is here |
|------|----------------|
| [`webapps/`](webapps/) | Richest PHP werf-raw: env/cluster `fl.value` pluck, hook Jobs, New Relic, VPA off |
| [`dashboard/`](dashboard/) | Frontend werf-raw: builder artifact, DexAuthenticator, production S3 sync Job |

I did not add a stub Chart.yaml. `helm lint` against these trees fails on purpose. Render path is `werf render --env <env>`.

**Keywords:** werf, Helm without Chart.yaml, PHP-FPM, supercronic, Dex, object storage
