# Helmfile CI image

**Business first:** a deploy job has Helm, helmfile, and helm-diff in one image. Optional kubectl is a build-arg, not a second Dockerfile.

I used two tags from this file: baseline (no kubectl) and the same layers plus kubectl 1.34.3. Base is `alpine/helm:3.18.6`. Helmfile 0.169.1. `ENTRYPOINT` is cleared so GitLab can run `/bin/sh` scripts.

```text
helmfile/
  Dockerfile
  .gitlab-ci.yml    # two manual tags to example.registry/ci/helmfile
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| helm-diff plugin | Plan is a diff, not a hope |
| `KUBECTL_VERSION` ARG | One Dockerfile, two tags |
| Empty ENTRYPOINT | Helm base image would swallow the job script |
| Manual GitLab jobs | Push on `main` only when someone clicks |

```bash
docker build -t example.registry/ci/helmfile:0.169.1-helm3.18.6 \
  --build-arg KUBECTL_VERSION= \
  -f Dockerfile .

docker build -t example.registry/ci/helmfile:0.169.1-helm3.18.6-kubectl1.34.3 \
  --build-arg KUBECTL_VERSION=v1.34.3 \
  -f Dockerfile .
```

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).
