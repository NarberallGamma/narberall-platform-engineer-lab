# Sanitize before publish (CI)

This catalog publishes **pipeline shape**, not production CI trees. Living kits sit under [`pipelines/`](pipelines/).

- No client / employer names, runner tags that identify a company, or internal GitLab / Jenkins URLs
- No Vault paths, token variable names that match a live estate, or kube context names
- No real hostnames, CIDRs, or inventory files
- Job images and `resource_group` stay generic (`hashicorp/terraform:1.5`, `vmware-apply`, `example.registry`)
- Copy as `*.yml.example` / `*.yaml.example` / `Jenkinsfile.example`. Live `.gitlab-ci.yml` from a private repo stays private
- Scripts stay `*.sh`. Do not rename them to `.example`
- Docs/LLM jobs: describe **local** models only; do not commit prompts that embed tenant facts
- One richest include per mechanic. Do not publish a farm of near-identical service stubs
- Do not invent `jobs/build/*` or an **OSV-Scanner** job. Those files were not in the cleaned trees. Hub includes that pointed at missing build YAML stay commented
- Trivy job body stays in `werf-retail`. Sonar and AppSec tool includes stay in `java-gradle` and `werf-retail`. `security-gates/` is the consumer + scripts only
- Helm / Argo secrets: no kubeconfig, repository or cluster secrets, or `secret-values.yaml`. Detail: [`../helm/SANITIZE.md`](../helm/SANITIZE.md)

Terraform sanitize: [`../terraform/SANITIZE.md`](../terraform/SANITIZE.md).
