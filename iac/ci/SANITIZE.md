# Sanitize before publish (CI)

This catalog publishes **pipeline shape**, not production CI trees.

- No client / employer names, runner tags that identify a company, or internal GitLab / Jenkins URLs
- No Vault paths, token variable names that match a live estate, or kube context names
- No real hostnames, CIDRs, or inventory files
- Job images and `resource_group` stay generic (`hashicorp/terraform:1.5`, `vmware-apply`)
- Copy as `*.yml.example` / `Jenkinsfile.example`. Live `.gitlab-ci.yml` from a private repo stays private
- Docs/LLM jobs: describe **local** models only; do not commit prompts that embed tenant facts
- App / Java / Jenkins pipeline code waits for a later sanitize pass; this catalog may describe stages before the YAML lands
- Helm / Argo secrets: no kubeconfig, repository or cluster secrets, or `secret-values.yaml`. Detail: [`../helm/SANITIZE.md`](../helm/SANITIZE.md)

Terraform sanitize: [`../terraform/SANITIZE.md`](../terraform/SANITIZE.md).
