# Playwright e2e (ENV in the image)

**Business first:** the e2e job is a **build that runs Playwright**, with stand accounts as `ENV`, not a long-lived app image. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). Env-file sibling: [`../e2e-envfile/`](../e2e-envfile/). SPA under test: [`../node-nginx-spa/`](../node-nginx-spa/).

I used this file next to the nginx SPA. Chromium comes from `apk`. Playwright skips its own browser download. Operator / client / partner logins are `CHANGE_ME` defaults in the Dockerfile. Unused `NGINX_IMAGE` / `NPM_COMMAND` ARGs stay as in the source (this file sat beside the SPA build). The test tree is not in git.

```text
e2e/
  Dockerfile    # node:20-alpine, apk chromium, ENV accounts, npm run test:e2e
```

```bash
# from this directory, after the front + Playwright tree is the context:
docker build -t example.registry/shop-app/e2e:local \
  --build-arg E2E_TEST_BASE_URL=https://e2e.example.com \
  --build-arg E2E_TEST_NAMES=smoke \
  .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Test as `RUN` | The image is the job. Green build means the suite ran |
| Accounts as `ENV` | Stand users live in the Dockerfile (placeholders here) |
| Host Chromium | `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` + Alpine packages |
| `CI=true` | Playwright CI defaults |

## Honest gap

App source, Playwright specs, and real passwords are not in this folder. `COPY . /app` expects that tree. A rebuild from this directory alone fails.

This is **not** [`../e2e-envfile/`](../e2e-envfile/). That file re-declares ARGs after `FROM` and copies `.env.e2e.<stand>` so accounts stay out of the Dockerfile.

**Keywords:** Playwright, Chromium, e2e, ENV, node 20 Alpine
