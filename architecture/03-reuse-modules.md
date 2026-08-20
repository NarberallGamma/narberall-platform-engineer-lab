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
| [`practice/workstation/reference/scripts/`](../practice/workstation/reference/scripts/) | SSH / kube / Ansible / JSM helpers any agent host calls (Cursor, Claude Code, Codex, local) | Hours on a new laptop; same kit, any of those OS |
| [`iac/ansible/reference/monitoring-starter/`](../iac/ansible/reference/monitoring-starter/) | Host metrics | Minutes via Ansible |
| [`iac/ansible/reference/ansible-llm-collab/`](../iac/ansible/reference/ansible-llm-collab/) | GPU/LLM + Nextcloud + Kafka + CIS | Hours once inventory and GPU host exist |
| [`iac/ansible/reference/ansible-estate/`](../iac/ansible/reference/ansible-estate/) | docker_app family + Vault + hibernate + RDS Flyway/RO/RW users | Hours for one app after SSH and images exist |
| [`iac/ansible/reference/ansible-app-platform/`](../iac/ansible/reference/ansible-app-platform/) | Kafka mTLS, EDR, Prometheus, Postgres users | Hours after hosts are inventory |
| [`iac/ansible/reference/ansible-kb-linux/`](../iac/ansible/reference/ansible-kb-linux/) | PostgreSQL / Percona / NTP / host audit | Hours for a Linux DB or NTP estate |
| [`iac/ansible/reference/ansible-backup-borg/`](../iac/ansible/reference/ansible-backup-borg/) | Borg user + dump scripts | Hours once the backup host and keys exist |
| [`iac/ansible/reference/ansible-aws-hosts/`](../iac/ansible/reference/ansible-aws-hosts/) | AWS bastion / DB / disks / users | Hours next to [`../iac/terraform/aws/`](../iac/terraform/aws/) |
| [`iac/helm/reference/helm-estate-cluster/`](../iac/helm/reference/helm-estate-cluster/) | Istio policies, Kafka Connect, Vault/ESO, Argo bootstrap, LB, ingress, Zalando, obs overlay | Hours once the cluster exists |
| [`iac/helm/reference/helm-mesh-eso/`](../iac/helm/reference/helm-mesh-eso/) | Istio 1.30.3 `base`+`istiod` and ESO 2.9.0 install | Hours once the cluster exists |
| [`iac/helm/reference/helm-data-plane/`](../iac/helm/reference/helm-data-plane/) | Linkerd, Jaeger, NiFi (shop-class mesh contrast) | Hours once the cluster exists |
| [`iac/helm/reference/helm-addons-extra/custom-prometheus-rules/`](../iac/helm/reference/helm-addons-extra/custom-prometheus-rules/) | Deckhouse PromQL pack (12 templates, env-gated) | Hours once Prometheus / Deckhouse exists |
| [`iac/helm/reference/helm-addons-extra/elastalert2/`](../iac/helm/reference/helm-addons-extra/elastalert2/) | Log runtime alerts + Falco on Elasticsearch | Hours once ES exists |
| [`iac/helm/reference/helm-addons-extra/elk/`](../iac/helm/reference/helm-addons-extra/elk/) | ECK overlay (5-node ES, Kibana+Dex, ILM Job) | A day once the logging pool exists |
| [`iac/helm/reference/helm-addons-extra/opentelemetry-collector/`](../iac/helm/reference/helm-addons-extra/opentelemetry-collector/) | OTel Operator CR overlay | Hours once the operator exists |
| [`iac/helm/apps/`](../iac/helm/apps/) | Product samples hub (one richest copy per mechanic) | Hours to pick a packaging shape once the cluster and secrets path exist |
| [`iac/helm/apps/treasury-keycloak/`](../iac/helm/apps/treasury-keycloak/) | Keycloak overlay: codecentric 17.0.2, managed PG, ExternalSecret | Hours once Vault/ESO and RDS-class Postgres exist. Vendor tree stays a pin |
| [`iac/helm/apps/treasury-ved-pattern/`](../iac/helm/apps/treasury-ved-pattern/) | Estate umbrellas: `file://` base-chart / front-base, CryptoPro, gRPC, monolith overlay | Hours per mechanic after the shared lib and ClusterSecretStore exist |
| [`iac/helm/apps/icon-pro-sample/`](../iac/helm/apps/icon-pro-sample/) | Shop-class `.helm` pair (gateway + keycloak) | Hours for one service after values exist. Not twenty-seven backends |
| [`iac/helm/apps/helmfile-dev/`](../iac/helm/apps/helmfile-dev/) | Two DEV helmfiles + local charts | Minutes to hours for a DEV namespace once images exist |
| [`iac/helm/apps/chart-flant-lib/`](../iac/helm/apps/chart-flant-lib/) | Chart.yaml + HTTPS flant-lib | Hours once the chart lands and the library repo is reachable |
| [`iac/helm/apps/chart-local-subchart/`](../iac/helm/apps/chart-local-subchart/) | Chart.yaml + local subchart | Hours once the chart lands |
| [`iac/helm/apps/werf-raw/`](../iac/helm/apps/werf-raw/) | werf + `.helm/` without Chart.yaml | Hours once werf and a registry exist |
| [`iac/helm/apps/oci-common-app/`](../iac/helm/apps/oci-common-app/) | Chart + OCI `common` library | Hours once the OCI registry is reachable. Library tarball is not in git |
| [`iac/helm/apps/werf-monorepo-sample/`](../iac/helm/apps/werf-monorepo-sample/) | Shared werf values + one unit | Hours to wire `WERF_VALUES_1` after the common-templates pack exists |

Sentence a buyer can quote: **this library is how I stand up a HA EKS / CCE / GKE-class cluster with a monitoring starter in hours, and a VPC+compute baseline in minutes, once access is ready.** GKE follows the same ownership pattern; the published live tree is AWS. Huawei-class CCE is in [`../iac/terraform/cloud-ru-compute/`](../iac/terraform/cloud-ru-compute/).

Existing module list is unchanged: [`../iac/terraform/modules/README.md`](../iac/terraform/modules/README.md).
