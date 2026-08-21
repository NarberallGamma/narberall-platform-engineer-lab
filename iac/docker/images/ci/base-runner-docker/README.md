# Docker-login CI runner

**Business first:** a Kaniko-less job still needs `docker login`, `git`, and `rsync` on a thin Alpine, not a full DinD image.

I used this image on GitLab jobs that push or rsync after a registry login. `init.sh` logs in with the job payload (`CI_REGISTRY_*`) and, when set, an explicit GitLab registry triple. The static Docker **client** 26.1.1 is in the image. The daemon is the service next to the job.

Not a copy of [`../base-runner-k8s/`](../base-runner-k8s/). That tree is kubectl and Helm. This tree is docker-cli login.

```text
base-runner-docker/
  Dockerfile
  init.sh
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Static `docker` 26.1.1 | Client only |
| Two login paths | Job payload vs named CI variables |
| `rsync` + `git` | Promote and sync after login |

```bash
docker build -t example.registry/ci/base-runner-docker:26.1.1 -f Dockerfile .
```

Sanitize: [`../../../SANITIZE.md`](../../../SANITIZE.md).
