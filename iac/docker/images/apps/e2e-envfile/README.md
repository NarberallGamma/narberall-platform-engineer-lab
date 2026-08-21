# Playwright e2e (env-file per stand)

**Business first:** stand accounts belong in **`.env.e2e.<stand>`**, not as a dozen `ENV` lines in the Dockerfile. Hub: [`../../../`](../../../). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md). ENV sibling: [`../e2e/`](../e2e/).

I used this variant when the same Playwright suite ran on several stands. `E2E_ENV_FILE` is re-declared **after** `FROM` so `docker build --build-arg` reaches `ENV` (an ARG before `FROM` is visible only in `FROM`). The job copies that file to `.env.e2e` (what `playwright.config.ts` dotenv loads). `E2E_TEST_BASE_URL` from the job wins; an empty value is unset so it does not force localhost. The env files and the test tree are not in git.

```text
e2e-envfile/
  Dockerfile    # ARG after FROM, cp $E2E_ENV_FILE → .env.e2e, then npm run test:e2e
```

```bash
# from this directory, after the front + Playwright tree and .env.e2e.<stand> are the context:
docker build -t example.registry/shop-app/e2e-envfile:local \
  --build-arg E2E_ENV_FILE=.env.e2e.dev \
  --build-arg E2E_TEST_BASE_URL=https://e2e.example.com \
  --build-arg E2E_TEST_NAMES=smoke \
  .
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| ARG after `FROM` | Build-args survive the `FROM` reset. Comment in the file states that |
| Env-file copy | `cp "$E2E_ENV_FILE" .env.e2e` is the Playwright contract |
| URL override | Job URL beats the file. Empty URL is unset |
| Same Chromium pin | Alpine chromium + `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` |

## Honest gap

App source, Playwright specs, and `.env.e2e.<stand>` files are not in this folder. The `cp` line expects those files. A rebuild from this directory alone fails.

This is **not** [`../e2e/`](../e2e/). That file bakes operator / client / partner `ENV` into the image. This file keeps accounts in a stand file.

**Keywords:** Playwright, Chromium, e2e, dotenv, build-arg after FROM
