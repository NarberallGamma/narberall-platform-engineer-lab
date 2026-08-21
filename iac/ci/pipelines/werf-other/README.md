# Werf other (semantic-release, monorepo unit, review quota, werf run, OpenTofu)

**Business first:** five small pipelines that the retail and delivery kits do not cover: a tag after Dev, one monorepo unit factory, a review-stand quota, `werf run` for lint and unit tests, and OpenTofu drift against a hypervisor count. Buyer page: [`../../../../docs/for-business.md`](../../../../docs/for-business.md). Hub: [`../../`](../../).

I used these as **separate GitLab project roots**, not one mega include. The hub at this folder root is werf 2 plus semantic-release. The four subfolders are mini-roots: copy that folder as the project root, or include the `.example` paths as-is in a lab project. Not Trivy. Not SonarQube. Those gates live in the sibling retail kit ([`../werf-retail/`](../werf-retail/)). Review start/stop and canary live in [`../werf-delivery/`](../werf-delivery/).

Brand names, live GitLab hosts, and runner tags that named a dedicated werf pool are stripped. Job bodies stay intact. Charts and `werf.yaml` stay with the app (lab samples: [`../../../helm/apps/werf-monorepo-sample/`](../../../helm/apps/werf-monorepo-sample/), [`../../../helm/apps/werf-raw/webapps/`](../../../helm/apps/werf-raw/webapps/)). Sanitize: [`../../SANITIZE.md`](../../SANITIZE.md).

```text
werf-other/                          # hub mini-root (werf 2 ea)
  common.yml.example                 # Build / plan / converge / cleanup, RUNNER_TAG docker
  multiStageMain1.2.yml.example
  releaseDeploy.yml.example          # semantic-release after Deploy to Dev, tag-gated prod
  releaseDeploy_nodejs_front_spa.yml.example
  singleStageInfra1.2.yml.example
  tests/nodeCodeStyle.yml.example    # spec:inputs ESLint / Prettier on werf-built images
  monorepo-unit/                     # mini-root: one spec:inputs factory consumer
    unit.gitlab-ci.yml.example
    services-template.yml.example
    script-test.yml.example          # coverage ratchet vs generic packages
    common.yml.example               # parent hidden jobs (Build, .multi_deploy_*)
  php-review-quota/                  # mini-root
    webapps.gitlab-ci.yml.example    # MAX_REVIEW helm-list + phpcs-on-diff + dual cluster
  werf-run-builder/                  # mini-root
    .gitlab-ci.yml.example
    .gitlab/{common,make-builder,tests,build-bundle,deploy,review,test-e2e,cleanup}.yaml.example
  opentofu/                          # mini-root
    opentofu.gitlab-ci.yml.example   # OpenTofu component 0.45.0 + SAST-IaC + drift alert
```

This folder is catalog YAML (`*.yml.example` / `*.yaml.example`). A consumer copies the needed files to live names in a private app repo. Each mini-root resolves its own `include: local:` graph. The hub and `werf-run-builder/` must not share one GitLab project root: hub includes are `/common.yml.example`, builder includes are `.gitlab/*.yaml.example`.

## What hiring should see

| Piece | Why it is here |
|-------|----------------|
| `releaseDeploy.yml.example` | `semantic-release` after Deploy to Dev, then tag-gated production. Skip when only `CHANGELOG.md` changes. |
| `tests/nodeCodeStyle.yml.example` | GitLab `spec:inputs` for image and env suffix. Four includes from the SPA hub (dev / SSR / production). |
| `monorepo-unit/services-template.yml.example` | Unit factory: path `changes:`, `.disabled-` job prefix, cobertura, optional db-dump and e2e `trigger:`. |
| `monorepo-unit/script-test.yml.example` | Coverage ratchet against a GitLab generic package. Fail when coverage drops. |
| `php-review-quota/webapps.gitlab-ci.yml.example` | `MAX_REVIEW` from `helm list`, docker-build `php-tools-ci` + phpcs on git-diff paths, `WERF_SET_CLUSTER` for two contexts. |
| `werf-run-builder/.gitlab/make-builder.yaml.example` | `werf build builder` then `werf run builder` for lint and unit. Review URL from `werf render` Ingress. Ephemeral e2e NS + cross-repo `trigger: depend`. |
| `opentofu/opentofu.gitlab-ci.yml.example` | Official OpenTofu job templates plus GitLab SAST-IaC. Scheduled job compares TF state resource count to hypervisor VMs. |

```bash
# hub mini-root: GitLab project root = this folder
# include:
#   - local: /releaseDeploy.yml.example

# monorepo-unit mini-root: GitLab project root = monorepo-unit/
# include:
#   - local: common.yml.example
#   - local: unit.gitlab-ci.yml.example

# werf-run-builder mini-root: GitLab project root = werf-run-builder/
# include:
#   - local: .gitlab-ci.yml.example
```

The monorepo unit extends hidden jobs from `monorepo-unit/common.yml.example`. Include that file in the same pipeline. The unit file itself does not list it (parent-hub shape).

## Honest gaps

- One monorepo unit, not a generated farm. The factory shape is here; sibling units stay out.
- No `werf.yaml` and no Helm charts. `WERF_CONFIG` still points at `.werf/portal-api/werf.yaml` as a runtime path.
- `monorepo-unit/script-test.yml.example` is flattened next to the template. The live estate kept that file under the helm directory.
- `php-review-quota` builds `php-tools-ci` from `.docker/images/php-for-ci/Dockerfile`. That Dockerfile is not in this catalog.
- No OSV-Scanner job. No Trivy or SonarQube in this tree.
- Downstream `trigger:` projects (`shop-app/e2e`, `shop-app/dashboard-api`, `infra/db-dump-for-dev`) are placeholders until those repos exist.
- OpenTofu `component:` and `Jobs/SAST-IaC.gitlab-ci.yml` are GitLab catalog / template includes, not files in this folder.
- `notify-alert` in the OpenTofu drift job is a placeholder CLI name. Tokens and the GitLab project id are `CHANGE_ME`.
- Cleanup jobs still read `WERF_IMAGES_CLEANUP_PASSWORD` from CI variables. A live token must not land in git.

**Keywords:** werf, GitLab CI, semantic-release, spec:inputs, monorepo, cobertura, review quota, phpcs, werf run, OpenTofu, SAST-IaC
