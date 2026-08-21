# Common CI (collab, thin)

**Business first:** image builds and host Ansible sync share one include tree so a consumer repo is a thin `.gitlab-ci.yml`, not a copy of job bodies. This is the **thin** variant: three Kaniko jobs plus one Ansible host sync. The richer estate tree (registry-init, Helm/Argo, extra images, release cutover) is the sibling estate kit, not this folder.

I used this shape on a collab and cybersec estate. Consumers include the files. The pipeline runs in the consumer context (`CI_REGISTRY_IMAGE` and that repo tree). Job bodies stay here.

Hunter map: [`../`](../). CI hub: [`../../`](../../). Build context: [`../../../docker/images/ci/`](../../../docker/images/ci/). Host metrics compose: [`../../../docker/compose/sec-stack/`](../../../docker/compose/sec-stack/). Ansible extra that copies that stack: [`../../../ansible/reference/ansible-llm-collab/extras/sec-stack/`](../../../ansible/reference/ansible-llm-collab/extras/sec-stack/). Richer sibling: [`../common-ci-estate/`](../common-ci-estate/). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

This folder is **not** a second estate common-ci project. Consumer samples use `project: collab/common-ci` so the richer estate file does not win by path.

```text
common-ci-collab/
  defaults.yaml.example              # BASE_IMAGE / KANIKO_IMAGE pins
  builds/
    kaniko-build.yaml.example        # bootstrap from gcr.io Kaniko debug
    ansible-build.yaml.example       # creator-ee image via $KANIKO_IMAGE
    base-runner-build.yaml.example   # docker login / rsync / git runner
  deploys/
    ansible-deploy.yaml.example      # runner_host or SSH custom_host
  includes/
    ansible.gitlab-ci.yml.example    # spec:inputs forward into the deploy file
    base-images.gitlab-ci.yml.example
  sec-stack/
    sec-stack.gitlab-ci.yml.example  # lint + Terragrunt + SOPS/Ansible
  README.md
```

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| Thin include split | `includes/` is two consumer shapes. `base-images` lists three builds. `ansible` forwards `spec: inputs` into the deploy file. |
| Three Kaniko jobs | Same names as the estate kit (kaniko, ansible, base-runner). Timeout is 2h. Context is `$CI_PROJECT_DIR/<dir>` only. |
| `ansible-deploy` | `runner_host` rsyncs onto `/ansible` (needs runner volumes). `custom_host` is SSH from `main` when `DEPLOY_TARGET_HOST` is set. Optional Vault `.env.vault` and a decoded SSH key on the synced tree. |
| `defaults.yaml.example` | One pin for `$BASE_IMAGE` and `$KANIKO_IMAGE`. Ansible and base-runner include it with `local: '/defaults.yaml.example'`. |
| `sec-stack` | Lint on MR/main. `plan:cloud` / `apply:cloud` only when `OS_AUTH_TOKEN` is set. Apply is manual on `main` with `resource_group`. Deploy decrypts SOPS and runs `playbooks/site.yml`. |

```yaml
# consumer (base-images): job bodies stay in collab/common-ci
include:
  - project: 'collab/common-ci'
    file: 'builds/kaniko-build.yaml.example'
    ref: main
```

Catalog copies keep the `.example` suffix. A live GitLab project drops that suffix and points `file:` / `local:` at the live names.

## Honest gaps

- No hub `.gitlab-ci.yml` and no `registry-init` in this tree.
- `kaniko-build` does not include defaults. The first image is `gcr.io/kaniko-project/executor:debug`.
- Dockerfiles are not here. Pins live under [`../../../docker/images/ci/`](../../../docker/images/ci/).
- `mint-cloud-token.py` is named in sec-stack comments only. The helper is not in this kit.
- A stock Auto-DevOps template include had no custom job body and is not published.
- Nested `include: local: '/defaults.yaml.example'` must resolve against the common-ci project. Consumer repos do not ship that file.
- No OSV job. No extra image builds (certs, exporters, hibernate). No Helm/Argo/Vault/Kafka deploys. No release cutover.
- Two extra files named in an older README (registry locations, timezone notes) were never in this tree.

**Keywords:** GitLab CI, include, Kaniko, Ansible, Terragrunt, SOPS, VictoriaMetrics, runner_host
