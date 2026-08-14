# Sanitized pipelines

One folder entry per published pipeline. This list grows as private CI is cleaned and moved here.

The **full map** (infra create → accompany → Java and other builds → publish → gates → MR → deploy → update → revoke/cleanup, Jenkins and GitLab CI) lives in the hub: [`../README.md`](../README.md).  
Diagrams: [`../../../diagrams/iac/ci-turnkey.md`](../../../diagrams/iac/ci-turnkey.md).  
Terraform those jobs call: [`../../terraform/`](../../terraform/).  
Ansible those jobs call: [`../../ansible/`](../../ansible/).

| Pipeline | Tool | What it runs |
|----------|------|----------------|
| [`host-lifecycle.gitlab-ci.yml.example`](host-lifecycle.gitlab-ci.yml.example) | GitLab CI | Plan → apply → SSH → Ansible → Vault → monitoring → docs |

**Described in the hub, code not in this folder yet:** JVM / Java build includes, publish + promote, Argo sync, auto-MR, revoke / preview teardown, Jenkinsfile equivalents. Same best-practice stages; sanitize next.
