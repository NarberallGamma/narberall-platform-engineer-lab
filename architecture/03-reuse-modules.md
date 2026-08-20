# Reusable units (apply again next week)

**Business:** the second environment should be a **parameter change**, not a second project. Published units are sanitized slices, not a marketplace one-click. The claim is the **calendar** once credentials and DNS exist.

| Unit | What it is for | Honest time-to-value |
|------|----------------|----------------------|
| [`iac/terraform/modules/`](../iac/terraform/modules/) | Huawei-class VPC, subnet, SG, EIP, compute | Minutes for a network+VM apply after inputs exist |
| [`iac/terraform/aws/live/`](../iac/terraform/aws/live/) | Account/region/env Terragrunt; EKS + Karpenter-class placeholder | Hours to a day for a HA EKS-class cluster + monitoring starter, not a quarter |
| [`iac/terraform/examples/greenfield-platform/`](../iac/terraform/examples/greenfield-platform/) | Compose the modules | Same day as the first apply |
| [`iac/ci/pipelines/host-lifecycle.gitlab-ci.yml.example`](../iac/ci/pipelines/host-lifecycle.gitlab-ci.yml.example) | Plan → apply → Ansible → Vault → metrics → docs | One pipeline, one host, minutes after runners exist |
| [`practice/home-lab/reference/ai/llm-compose-kit/`](../practice/home-lab/reference/ai/llm-compose-kit/) | Ollama-class GPU serve | Minutes on a box that already has NVIDIA + Compose |
| [`practice/workstation/reference/mcp-replicate/`](../practice/workstation/reference/mcp-replicate/) | Replicate MCP wrapper + `replicate-img` (async poll) | Minutes on Linux, macOS, or WSL once a token file exists |
| [`practice/workstation/reference/scripts/`](../practice/workstation/reference/scripts/) | SSH / kube / Ansible / JSM helpers the IDE agent calls | Hours on a new laptop; same kit, any of those OS |
| [`iac/ansible/reference/monitoring-starter/`](../iac/ansible/reference/monitoring-starter/) | Host metrics | Minutes via Ansible |
| [`iac/ansible/reference/ansible-llm-collab/`](../iac/ansible/reference/ansible-llm-collab/) | GPU/LLM + Nextcloud + Kafka + CIS | Hours once inventory and GPU host exist |
| [`iac/ansible/reference/ansible-estate/`](../iac/ansible/reference/ansible-estate/) | docker_app family + Vault + hibernate + RDS Flyway/RO/RW users | Hours for one app after SSH and images exist |
| [`iac/ansible/reference/ansible-app-platform/`](../iac/ansible/reference/ansible-app-platform/) | Kafka mTLS, EDR, Prometheus, Postgres users | Hours after hosts are inventory |
| [`iac/ansible/reference/ansible-kb-linux/`](../iac/ansible/reference/ansible-kb-linux/) | PostgreSQL / Percona / NTP / host audit | Hours for a Linux DB or NTP estate |
| [`iac/ansible/reference/ansible-backup-borg/`](../iac/ansible/reference/ansible-backup-borg/) | Borg user + dump scripts | Hours once the backup host and keys exist |
| [`iac/ansible/reference/ansible-aws-hosts/`](../iac/ansible/reference/ansible-aws-hosts/) | AWS bastion / DB / disks / users | Hours next to [`../iac/terraform/aws/`](../iac/terraform/aws/) |

Sentence a buyer can quote: **this library is how I stand up a HA EKS / CCE / GKE-class cluster with a monitoring starter in hours, and a VPC+compute baseline in minutes, once access is ready.** GKE follows the same ownership pattern; the published live tree is AWS. Huawei-class CCE is in [`../iac/terraform/cloud-ru-compute/`](../iac/terraform/cloud-ru-compute/).

Existing module list is unchanged: [`../iac/terraform/modules/README.md`](../iac/terraform/modules/README.md).
