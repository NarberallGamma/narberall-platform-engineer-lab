# Sanitized pipelines

One row per published kit. The **full map** (infra create → accompany → Java and other builds → publish → gates → MR → deploy → update → revoke/cleanup, Jenkins and GitLab CI) lives in the hub: [`../README.md`](../README.md).  
Case: [`../../../case-studies/13-ci-pipelines.md`](../../../case-studies/13-ci-pipelines.md).  
Diagrams: [`../../../diagrams/iac/ci-turnkey.md`](../../../diagrams/iac/ci-turnkey.md).  
Terraform those jobs call: [`../../terraform/`](../../terraform/).  
Ansible those jobs call: [`../../ansible/`](../../ansible/).  
Build context: [`../../docker/images/`](../../docker/images/).

Catalog YAML is `*.yml.example` / `*.yaml.example` / `Jenkinsfile.example`. Scripts stay `*.sh`.

| Kit | Tool | What it runs |
|-----|------|----------------|
| [`host-lifecycle.gitlab-ci.yml.example`](host-lifecycle.gitlab-ci.yml.example) | GitLab CI | Plan → apply → SSH → Ansible → Vault → monitoring → docs |
| [`common-ci-estate/`](common-ci-estate/) | GitLab CI | Shared Kaniko / Helm / Argo / Vault / Kafka includes. Nested `releases/` (cutover, revert, Ansible VM, auto MR) |
| [`common-ci-collab/`](common-ci-collab/) | GitLab CI | Thinner Kaniko trio + Ansible host sync + sec-stack Terragrunt / SOPS |
| [`java-gradle/`](java-gradle/) | GitLab CI | Five runtime hubs. Sonar, Allure, Helm deploy, Playwright, backup, AppSec tools. `jobs/build/*` commented |
| [`review-stand/`](review-stand/) | GitLab CI | Time-boxed review namespace: create, OCI Helm upgrade, expiry cleanup |
| [`images-kaniko/`](images-kaniko/) | GitLab CI | Manual Kaniko pin catalog (retag into the project registry) |
| [`shop-test-allure/`](shop-test-allure/) | GitLab CI | Gradle + Chrome UI and Newman API, then Allure upload |
| [`werf-retail/`](werf-retail/) | GitLab CI + werf | Multi-stage, Trivy / Grype / SAST, Sonar, cleanup, review, ReleaseCI, one BI env |
| [`werf-delivery/`](werf-delivery/) | GitLab CI + werf | Review start/stop, canary overlay, Slack notify, PHP gates, `werf cleanup` |
| [`werf-other/`](werf-other/) | GitLab CI + werf | Shared hub plus monorepo unit, PHP review quota, `werf run` builder, OpenTofu |
| [`jenkins/`](jenkins/) | Jenkins + GitLab CI | `Jenkinsfile.example` (build → push → AWX). Borg backup-monitor. Include stub of missing `infra/common-ci` |
| [`github-actions/`](github-actions/) | GitHub Actions | werf publish, Helm chart-testing / KinD, Go release matrix |
| [`helmfile-dev/`](helmfile-dev/) | GitLab CI | Two DEV pipelines: `docker build` then `helmfile apply` (llm + feed) |
| [`cluster-addons/`](cluster-addons/) | GitLab CI | Manual Istio + External Secrets Operator upgrade / rollback |
| [`kb-example-ci/`](kb-example-ci/) | GitLab CI + werf | One teaching `werf converge` (test / production) |
| [`security-gates/`](security-gates/) | GitLab CI | DefectDojo / Dependency-Track consumer + scripts. Not a Trivy/Sonar mega-folder |

**Not a row:** OSV-Scanner (no source YAML, not invented). `jobs/build/*` (commented on the Java hubs, not written). Helmfile **image** CI (stays next to [`../../docker/images/ci/helmfile/`](../../docker/images/ci/helmfile/)).
