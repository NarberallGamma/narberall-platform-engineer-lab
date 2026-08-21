# Review stand (time-boxed namespace)

**Business first:** a branch gets a **short-lived stand** with an expiry stamp, not a leftover namespace that someone has to remember to delete.

I used this hub when a reviewer needed a namespace, shared TLS/trust, Postgres/Kafka/MinIO, and a slice of shop services under one GitLab trigger. Child pipelines do the work. The parent file only chooses start-app, start-all, or cleanup.

Hunter map: [`../../`](../../). Pin catalog that feeds image tags: [`../images-kaniko/`](../images-kaniko/). UI/API Allure run against a stand: [`../shop-test-allure/`](../shop-test-allure/). Charts after the push: [`../../../helm/`](../../../helm/).

Catalog YAML keeps the `.example` suffix. Hub `include: local:` paths match those names. Helm chart trees stay out of this folder.

```text
review-stand/
  .gitlab-ci.yml.example      # hub: start-app / start-all / start-cleanup
  app.yml.example             # service:tag list read by deploy-app
  ci/
    ns.yaml.example           # create/label/expire NS, stand deps, extend
    deploy-app.yaml.example   # OCI Helm pull + upgrade template + 12 jobs
    cleanup.yaml.example      # delete expired temp-stand=true namespaces
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Hub triggers | Manual `start-app` and `start-all` use `strategy: depend`. Cleanup runs when `PIPELINE_TYPE == cleanup`. |
| Time-box | `create-ns` labels `temp-stand=true` and annotates `expires-at`. Extend jobs add 3h or 24h. Protected names are refused. |
| Stand deps | Helm upgrade for postgres / kafka / minio / roles, then clone jobs. `info` prints ingress and node-port hints. |
| `.deploy-template` | Job name after `deploy-` is the key in `app.yml.example`. OCI pull of `1.0.0-${IMAGE_TAG}`, then `helm upgrade` with `values-dev.yaml`. |
| Distinctive `deploy-*` | Twelve jobs, not a full shop farm. Extra sets cover Keycloak JDBC, gateway domain, vault profiles, audit topic, and a small `needs` graph. |
| Cleanup | Walk namespaces with `temp-stand=true` and delete those past `expires-at`. |

```bash
# to run as a live GitLab project: copy this folder to the repo root and drop the .example suffix
# include paths in the hub must drop the suffix in the same edit
# helm/postgres helm/kafka helm/minio helm/roles helm/postgres-clone.yml helm/s3-clone.tmpl.yml stay next to the project (not in this kit)
```

## Honest gaps

- Chart trees and `values/<ref>.yaml` are **runtime** paths. This kit is the pipeline shape, not a Helm farm.
- OCI charts come from `example.registry`. Login uses `$CI_REGISTRY_USER` / `$CI_REGISTRY_PASSWORD`.
- `clone-minio` expects `S3ID1` / `S3KEY1` / `S3ID2` / `S3KEY2` plus MinIO keys at runtime. Script placeholders are `CHANGE_ME`.
- `ns.yaml.example` `info` job `needs: deploy-shop-app`, which lives in `deploy-app.yaml.example`. Load both files (the hub `start-all` path) or that need is empty.
- Near-clone `deploy-*` services were not copied. One template plus the distinctive jobs is the published mechanic.
- Kube API address and token stay CI variables (`DEV_HELM_KUBEAPISERVER`, `DEV_HELM_KUBETOKEN`). No kubeconfig in git.

## Keywords

GitLab CI, review stand, preview namespace, Helm, OCI chart, expire, cleanup, Keycloak, Kafka, MinIO, Postgres
