# Helmfile DEV pipelines

**Business first:** a DEV namespace is two GitLab pipelines that `docker build` then `helmfile apply`. Charts stay in the Helm SAMPLE. Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

I used this pair when product charts lived in two repos and each pipeline applied its own helmfile against the same stand. One side builds `llm-api` (and a thin fleet-watcher job) then applies `stands/dev-stand-llm/helmfile.yaml`. The other builds three feed images and applies `stands/dev-stand-feed/helmfile.yaml`.

```text
helmfile-dev/
  llm/.gitlab-ci.yml.example     # dind build + helmfile apply + security trigger
  feed/.gitlab-ci.yml.example    # dind build of three images + helmfile apply
```

Helmfiles and local charts: [`../../../helm/apps/helmfile-dev/`](../../../helm/apps/helmfile-dev/).  
Deploy image build stays next to the Dockerfile: [`../../../docker/images/ci/helmfile/`](../../../docker/images/ci/helmfile/). That image CI is not copied here.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Two pipelines, one stand | Same split as the Helm SAMPLE. CI ran `helmfile apply -f` twice |
| `docker:dind` then `ci/helmfile` | Build on Docker-in-Docker. Apply uses the pin image (helmfile 0.169.x) |
| Manual `main` only | DEV apply is a click, not a merge side effect |
| Feed DNS pin | `docker build --dns` from the runner `resolv.conf` when cluster DNS was not enough |
| LLM `security-test` trigger | Child pipeline from [`../security-gates/`](../security-gates/) `templates/security-pipeline.yml.example` |

```bash
# apply after images exist (helmfile 0.169.x, Helm 3.18.x)
helmfile apply -f stands/dev-stand-llm/helmfile.yaml
helmfile apply -f stands/dev-stand-feed/helmfile.yaml
```

## Honest gaps

- App Dockerfiles and `werf.yaml` farms are not in this folder. Image pins are `example.registry/apps/{llm-api,feed-api,feed-rss,feed-bridge,fleet-watcher}`.
- `build:fleet-watcher` is still in the LLM file. The Helm SAMPLE dropped that chart (tokens in ConfigMap). The job stays as published; there is no chart here to apply it.
- `security-test` needs a GitLab project `security/security-gates` on `main`. The template lives in this catalog under [`../security-gates/`](../security-gates/).
- Istio install is [`../cluster-addons/`](../cluster-addons/) plus [`../../../helm/reference/helm-mesh-eso/`](../../../helm/reference/helm-mesh-eso/), not these helmfiles.

**Keywords:** GitLab CI, helmfile, Docker-in-Docker, DEV stand, llm-api, feed-api
