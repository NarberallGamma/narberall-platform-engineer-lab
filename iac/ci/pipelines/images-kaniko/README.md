# Images Kaniko (pin catalog)

**Business first:** public pins land in the **project registry** as named tags, so fifty Dockerfiles do not each `FROM` a floating Hub tag.

I used this file as a catalog of **manual** Kaniko jobs. Each job sets `NAME` and `VER`. If `$CI_PROJECT_DIR/$NAME/$VER/Dockerfile` is missing, the job writes a one-line `FROM $NAME:$VER` and retags into `$CI_REGISTRY_IMAGE`. That is a pin, not an image farm.

Hunter map: [`../../`](../../). Build context for the same pins: [`../../../docker/images/`](../../../docker/images/), especially [`../../../docker/images/ci/`](../../../docker/images/ci/). Case: [`../../../../case-studies/12-docker-images.md`](../../../../case-studies/12-docker-images.md). Review-stand consumes tags, not this catalog, at deploy time: [`../review-stand/`](../review-stand/).

This folder is one pipeline. Dockerfiles are not copied here.

```text
images-kaniko/
  .gitlab-ci.yml.example    # shared Kaniko template + one manual job per pin
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `.default_kaniko_template` | `gcr.io/kaniko-project/executor:v1.24.0-debug`, registry `config.json` from GitLab CI vars, `--cache=false`. |
| Missing Dockerfile | Create the version folder and a one-line `FROM`. The executor then pushes `$VER` and `$VER-$CI_COMMIT_SHORT_SHA`. |
| Push name | Dots and slashes in `NAME` become `-` so `gcr.io/kaniko-project/executor` is a legal repository path. |
| Pin list | Vault, Kafka, Gradle (11/17/21/25), Temurin, Liberica musl, Kaniko itself, Helm, Keycloak, Node 20/22/e2e, nginx. Twenty manual jobs. |
| Runner | Tag `k8s-kaniko`. Replace locally. |

```bash
# to run as a live GitLab project: copy .gitlab-ci.yml.example to .gitlab-ci.yml
# optional: place a real Dockerfile under $NAME/$VER instead of the one-line FROM fallback
```

## Honest gaps

- No Dockerfile tree in this kit. Sibling pins live under `iac/docker/images/ci/` (kaniko, jvm-base, liberica, node, helmfile). This file is the **pipeline** that retags.
- Jobs are `when: manual`. There is no schedule and no MR gate in this file.
- A single-image Kaniko build for a named estate image is a different kit (common-ci estate builds). This catalog is many pins in one file.
- Dockerfiles and `werf.yaml` farms are not invented here.

## Keywords

GitLab CI, Kaniko, image pin, registry retag, Gradle, Temurin, Liberica, Keycloak, Node
