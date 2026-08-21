# Case study: CI pipelines (GitLab, Jenkins, werf)

**Context:** estate and shop paths; shared includes plus one richest file per mechanic  
**Timeline:** host button first, then estate includes and Java hubs, then werf and Jenkins  
**Role:** Platform Engineer (CI owner)

This is **proof** that create, gate, promote, and revoke are pipelines, not a tribal checklist. [Case 12](12-docker-images.md) is the image build context. [Case 11](11-helm-estate.md) is the cluster package after the push. [Case 06](06-vmware-vcd-greenfield.md) is the VCD host the one-button file still calls. I used these includes so fifty services shared a hub, and these werf files so review and canary were a click, not a Friday `kubectl`.

Product pipelines exist as **one richest include per mechanic** under [`iac/ci/pipelines/`](../iac/ci/pipelines/). That is not a three-hundred-file dump of private `.gitlab-ci.yml`.

## Challenge

A shop with dozens of backends cannot paste the same fifty job files into every repo. An estate needs one include project for Kaniko, Helm, Argo, Vault, and a numbered release cutover. Review stands must expire. Retail wants Trivy and Sonar on the werf train; delivery wants canary and Slack, not a second copy of those gates. Jenkins is still real on earlier estates. Hunters should parse mechanics, not a private monorepo. Published gates in this lab are SonarQube and Trivy. OSV-Scanner is the same habit on estates that asked for it.

## Architecture

See diagram: [`diagrams/case-studies/13-ci-pipelines.md`](../diagrams/case-studies/13-ci-pipelines.md)

```text
1) host-lifecycle: terraform plan/apply → SSH → Ansible → Vault → monitoring → docs
2) common-ci-estate: shared builds/deploys + nested releases/ (MR, cutover, revert)
3) common-ci-collab: thinner Kaniko + Ansible + sec-stack (not a second estate hub)
4) java-gradle: five hubs; Sonar, Allure, deploy, e2e, backup, AppSec; jobs/build/* commented
5) review-stand + images-kaniko + shop-test-allure: preview NS, pin catalog, UI/API Allure
6) werf-retail: multi-stage + Trivy/Grype/SAST + Sonar + cleanup (no OSV)
7) werf-delivery: REVIEW-START/STOP, canary, notify, PHP gates
8) werf-other: monorepo unit, PHP review quota, werf run builder, OpenTofu
9) jenkins + github-actions: Jenkinsfile → AWX; three GHA workflows
10) helmfile-dev + cluster-addons + kb-example-ci + security-gates consumer
```

Honest scope: one include per mechanic. `jobs/build/*` stay commented. Helmfile **image** CI stays next to the Dockerfile. Seventy on-upgrade stubs stay out; the include lives under `common-ci-estate/releases/`.

## What shipped

- Host one-button GitLab file (VCD / Terraform path)
- Estate common-ci with nested release scripts so hub `include:` paths resolve
- Collab thin twin plus Terragrunt / SOPS sec-stack
- Java / Gradle hubs for generic, Gradle, JS, Python, and image-only services
- Review-stand expiry, Kaniko pin catalog, standalone Allure UI/API pipeline
- Retail werf: Trivy + Sonar + scheduled cleanup + one BI env
- Delivery werf: review, canary, Slack, PHPStan / Pest / Codecept
- Extra werf mechanics (four mini-roots), not a second retail dump
- Jenkinsfile (`docker.build` → registry → AWX) and a documented include 404
- GitHub Actions: werf publish, Helm KinD test, Go release
- Two DEV helmfile applies, manual Istio/ESO, one teaching `werf converge`
- Security-gates consumer + DefectDojo / Dependency-Track scripts (not a Trivy mega-folder)

## Results

- **Hours to attach a hub:** one `include:` instead of fifty copied job files. Review and canary are a click, not a Friday `kubectl`
- **Minutes after runners exist:** host one-button (plan → apply → Ansible → Vault → metrics → docs)
- **Ship:** branch or tag is the release. Cutover is a numbered pipeline. Preview NS expire
- SonarQube and Trivy are published job bodies. Helm is [case 11](11-helm-estate.md). Docker is [case 12](12-docker-images.md). This case is the button

## Stack

GitLab CI, Jenkins, GitHub Actions, Argo CD, werf, helmfile, Kaniko, Helm, Ansible, Terraform, Vault, SonarQube, Trivy, Grype, Semgrep, DefectDojo, Dependency-Track, Allure, Playwright, Newman, AWX

## Links

- CI hub: [`iac/ci/`](../iac/ci/)
- Kits: [`iac/ci/pipelines/`](../iac/ci/pipelines/)
- Host button: [`iac/ci/pipelines/host-lifecycle.gitlab-ci.yml.example`](../iac/ci/pipelines/host-lifecycle.gitlab-ci.yml.example)
- Estate include + releases: [`iac/ci/pipelines/common-ci-estate/`](../iac/ci/pipelines/common-ci-estate/)
- Java hubs: [`iac/ci/pipelines/java-gradle/`](../iac/ci/pipelines/java-gradle/)
- Trivy / Sonar (retail): [`iac/ci/pipelines/werf-retail/`](../iac/ci/pipelines/werf-retail/)
- Review / canary: [`iac/ci/pipelines/werf-delivery/`](../iac/ci/pipelines/werf-delivery/)
- Jenkinsfile: [`iac/ci/pipelines/jenkins/`](../iac/ci/pipelines/jenkins/)
- Sanitize: [`iac/ci/SANITIZE.md`](../iac/ci/SANITIZE.md)
- Images after the button: [`iac/docker/`](../iac/docker/), [case 12](12-docker-images.md)
- Helm after the push: [`iac/helm/`](../iac/helm/), [case 11](11-helm-estate.md)
- VCD host: [case 06](06-vmware-vcd-greenfield.md)
