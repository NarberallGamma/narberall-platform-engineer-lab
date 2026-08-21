# Node 20 Alpine (CI pin)

**Business first:** Node 20 jobs share one **retag** of the public `node:20-alpine` image.

This folder is a one-line `FROM`. Hiring should treat it as a registry retag, not a generated tutorial.

```text
node-20-alpine/
  Dockerfile    # FROM node:20-alpine
```

```bash
docker build -t example.registry/ci/node:20-alpine -f Dockerfile .
```

Siblings: [`../node-22-alpine/`](../node-22-alpine/) (retag plus `libc6-compat`), [`../node-e2e-ci/`](../node-e2e-ci/) (Chromium).

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).
