# OCI common library app (Helm)

**Business first:** I keep the product chart thin and pull shared ASP.NET helpers from an OCI library. The library tarball is not in git. `helm dependency build` talks to `oci://example.registry/helm/common`. Hub: [`../../`](../../). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

Werf builds the `app` and `nginx` images. Chart.yaml exports `werf` into the library so probes, wait-for-port init containers, and the Redis connection helper come from `common.*` and `fl.value`. One chart renders five stateless deployments (portal, counter, storefront, kiosk, jobs) by mutating values between includes. There is no local `_helpers.tpl`.

```text
oci-common-app/
  werf.yaml
  .helm/
    Chart.yaml                   # OCI deps: common (library) + review-jobs
    values.yaml                  # per-env maps, HPA/VPA, cluster_context
    secret-values.example.yaml
    templates/
      app.yaml                   # five includes of common.app.stateless.aspnet
      app-config.yaml            # ConfigMap per instance + Redis Secret
      service-headless.yaml      # headless gRPC Services
      job-flush-redis.yaml       # post-upgrade hook
      job-warmup-cache.yaml      # pre-upgrade hook
      nginx-for-dumps.yaml       # RWX PVC + nginx + cleanup CronJob
```

`helm dependency build` against Chart.yaml. Then werf converge. Render fails until the real OCI library is reachable. That is expected. The sample documents the contract, not a vendored copy of `common`.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| OCI library, not `file://` | Contrast with estate `base-chart` and the HTTPS `flant-lib` sample |
| `export-values` | Werf image tags and env land in the library |
| `fl.value` | `_default` / `stage` / `production` maps |
| `cluster_context` | AWS, etcd, and Sentry follow the cluster, not `werf.env` (DR stand) |
| Five instances | Same binary, different `SERVER_INSTANCE_TYPE`, replicas, HPA, ConfigMap suffix |
| Hooks | Flush Redis after upgrade. Warm up cache before. Skip on `cluster_type: reserve` |
| Dumps path | Production-only EFS PVC, nginx directory listing, 5-day CronJob. Counter instance runs `dump.sh` on preStop |

## Not this kit

- A second storefront chart that used the same OCI `common` dependency stays out. It had no `review-jobs` dep and fewer templates. One richest copy.
- The `common` and `review-jobs` chart trees are not in git. Pin is `0-latest` on the example registry.
- Live `secret-values.yaml` is not in git.

## Library contract (documented, not vendored)

| Chart | Pin | Helpers used | In git |
|-------|-----|--------------|--------|
| common (library) | 0-latest | `common.app.stateless.aspnet`, `common.container.aspnet`, `common.initContainer.waitPort`, `common.redis.configuration`, `common.env.custom`, `fl.value`, `fl.valueQuoted` | Chart.yaml only |
| review-jobs | 0-latest | export-values for MSSQL clone jobs on review stands | Chart.yaml + `review_jobs` values |

## Sanitize

Hosts are `*.example.com`. Tenant UUIDs are `00000000-0000-4000-8000-...`. Passwords are `CHANGE_ME`. OCI repos are `oci://example.registry/helm/common` and `oci://example.registry/helm/review-jobs`. Env matrix is `_default` / `stage` / `production` plus a `production-dr` cluster context.

**Keywords:** Helm, OCI, library chart, werf, ASP.NET, HPA, VPA, Deckhouse, gRPC
