# Dashboard (werf-raw SPA)

**Business first:** the staff UI is a **static artifact on nginx**, with Dex on non-prod and an object-storage publish Job on prod. Parent: [`../`](../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).

I kept `werf.yaml` and `.helm/` only. The JS monorepo stays out. Werf builds a Node builder, imports `apps/web/dist` into nginx, and keeps an `aws-cli` image for the upload Job.

```text
dashboard/
  werf.yaml                   # builder → static artifact → nginx + awscopy
  .gitignore
  .helm/
    values.yaml
    secret-values.example.yaml
    templates/
      dex.yaml                # Deckhouse DexAuthenticator, dev/stage
      portal/
        _helper.tpl           # affinity / tolerations / priority by env
        nginx-portal-cm.yaml
        nginx-portal-deployment.yaml
        ingress-portal.yaml
        aws-key-secret.yaml
        jobs-portal.yaml      # production s3 sync
        jobs-portal-cm.yaml
```

```bash
cp .helm/secret-values.example.yaml .helm/secret-values.yaml
# fill CHANGE_ME, then:
# werf render --env dev
# werf converge --env production
```

Build target follows `WERF_ENV`: `pnpm build:development` / `build:stage` / `build:production`.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| No Chart.yaml | Werf-raw. `.Chart.Name` comes from `project: dashboard` |
| Artifact import | `fromImage: builder` then `import` into nginx and aws-cli |
| Dex on non-prod | Ingress `auth-url` to a DexAuthenticator in the same namespace |
| Production upload Job | `aws s3 sync` against `s3_endpoint` / `bucket` from values |
| Nginx S3 fallback | `/static` and `/assets` try local files, then proxy the CDN host |
| Spread + VPA Off | `topologySpreadConstraints` on hostname, VPA updateMode Off |

## Secrets

`portal.job.aws_access_key_id` and `aws_secret_access_key` live in `.helm/secret-values.yaml` (gitignored). Example file uses `CHANGE_ME` only. The Secret template writes an AWS credentials file for the Job.

## What is not in git

- Application source (`apps/`, `packages/`)
- Live `secret-values.yaml` and `.werf_secret_key`
- GitLab CI and e2e jobs

**Keywords:** werf, SPA, nginx, Dex, Deckhouse, S3, AWS CLI
