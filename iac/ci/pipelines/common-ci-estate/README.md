# Estate common-ci (GitLab includes)

**Business first:** one shared include repo is the button for estate images, cluster operators, and a coordinated multi-repo release. A consumer repo includes a file. It does not copy the job bodies.

I used this tree as `estate/common-ci`: Kaniko pins, Helm and kubectl deploys, registry bootstrap, Ansible rsync onto the runner, and nested release automation under `releases/`. Brand, live registries, and runner tags that name a company are stripped. Job bodies stay so a reviewer can parse a real include hub, not a three-job demo.

Hunter map: [`../`](../). CI hub: [`../../`](../../). Build context: [`../../../docker/images/`](../../../docker/images/). Cluster charts: [`../../../helm/reference/helm-estate-cluster/`](../../../helm/reference/helm-estate-cluster/). Ansible sibling: [`../../../ansible/reference/ansible-estate/`](../../../ansible/reference/ansible-estate/). Thin collab twin: [`../common-ci-collab/`](../common-ci-collab/). Host create/accompany is a different file: [`../host-lifecycle.gitlab-ci.yml.example`](../host-lifecycle.gitlab-ci.yml.example). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

Includes in this tree already use the `.example` names so the hub, `/defaults.yaml.example`, and `releases/scripts` resolve as one project.

```text
common-ci-estate/
  .gitlab-ci.yml.example         # hub: defaults + registry-init + release includes
  defaults.yaml.example          # BASE_IMAGE / KANIKO_IMAGE pins
  registry-init.yaml.example     # create-regcred (manual)
  builds/                        # Kaniko jobs for estate images
  deploys/                       # Helm/kubectl + ansible rsync
  releases/                      # cutover, revert, on-upgrade-branch-push, scripts
    manifests/                   # generic shop-app / estate-ansible lists
    scripts/
  README.md
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Hub + `defaults.yaml.example` | One pin for `base-runner` and Kaniko. Consumers include `/defaults.yaml.example`. |
| `builds/*` | Manual Kaniko jobs for kaniko, base-runner, ansible EE, certs, hibernate, Temurin, two cloud exporters. |
| `deploys/*` | Argo CD, ESO, Vault ClusterSecretStore, Kafka/Strimzi, ingress/Istio/monitoring, site image, Ansible rsync to `/ansible`. |
| `releases/` | First-push MR, approve/merge cutover, optional revert, ansible VM deploy after sync. Scripts call the GitLab API. |
| Generic manifests | `shop-app` and `estate-ansible` lists. Not a live inventory. |

```yaml
include:
  - project: 'estate/common-ci'
    file: '/deploys/argocd.yaml.example'
    ref: main
```

Build jobs are included the same way from `builds/`. Each build job is `when: manual`. Only jobs whose context directory exists in the consumer repo should run (for example `base-images/ansible/` for `build-ansible`).

## Runner tags

| Jobs | Tag |
|------|-----|
| Kaniko image builds (`builds/*`, `deploys/web-site.yaml.example`) | `k8s-kaniko` |
| Helm / kubectl / rsync / release jobs | `docker` |

## Honest gaps

- Catalog YAML uses `*.yml.example` / `*.yaml.example`. GitLab loads `.gitlab-ci.yml` at the project root.
- `init.sh` and `create-regcred.sh` come from the base-runner image, not this tree.
- `generate-service-external-secrets.sh` lives in the consumer global-config repo.
- `run_docker_app.sh` lives in the ansible repo (`release-05`).
- Helm values, Argo repo/cluster manifests, and Dockerfiles are not here.
- No Trivy, SonarQube, or OSV jobs in this tree.
- `cluster-resources.yaml.example` declares stage `deploy-monitoring-ingress` with no job.
- `setup_gitlab_release_admin.sh` is a live-admin shape. Defaults fail closed on `CHANGE_ME`. Pointing it at a real GitLab from this catalog mutates that GitLab.

**Keywords:** GitLab CI, include, Kaniko, Harbor, Helm, Argo CD, External Secrets, Vault, Kafka, Strimzi, Ansible, release cutover, merge request
