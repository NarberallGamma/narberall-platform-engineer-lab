# Kaniko executor (CI pin)

**Business first:** the pipeline builds in-cluster without a Docker daemon. The image in the registry is a **retag** of the public Kaniko debug executor, not a home-grown builder.

This folder is a one-line `FROM`. Hiring should treat it as an honest registry pin, not a tutorial.

```text
kaniko/
  Dockerfile    # FROM gcr.io/kaniko-project/executor:debug
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| One-line `FROM` | Registry retag. I did not invent a Kaniko fork. |
| `:debug` tag | BusyBox shell for CI `before_script` |

```bash
docker build -t example.registry/ci/kaniko:debug -f Dockerfile .
```

Sibling pins: [`../jvm-base/`](../jvm-base/), [`../node-20-alpine/`](../node-20-alpine/). Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).
