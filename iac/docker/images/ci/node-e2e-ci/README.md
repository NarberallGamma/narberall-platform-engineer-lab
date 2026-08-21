# Node 22 E2E CI (Chromium)

**Business first:** browser tests run in CI with Chromium already in the image. The job does not apt-get a browser on every pipeline.

Alpine Node 22 plus `libc6-compat`, Chromium, fonts, `zip`, and `curl`. Same Node line as [`../node-22-alpine/`](../node-22-alpine/), extra packages for headless E2E.

```text
node-e2e-ci/
  Dockerfile
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Chromium on Alpine | Playwright / Puppeteer-class jobs |
| Fonts + nss + harfbuzz | Headless render, not a screenshot of a box |
| zip / curl | Artefact pack and health checks |

```bash
docker build -t example.registry/ci/node-e2e:22-alpine -f Dockerfile .
```

App-level E2E images live under the apps tree. This folder is the shared browser CI base.

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).
