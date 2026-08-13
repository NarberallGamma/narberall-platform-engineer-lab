# Cloud experience

Platforms I have stood up and operated: public cloud, private cloud, and on-prem. Each page is NDA-safe (sector and scale, not client names) and links to the Terraform that proves the same shape of work.

**cloud.ru note:** cloud.ru (and similar RU hyperscalers in this lab) is **Huawei Cloud class**. The resource model maps to **AWS** (VPC, ECS/EC2-class compute, CCE/EKS-class Kubernetes, RDS, OBS/S3, DMS/Kafka-class). That delivery is transferable AWS-shaped experience.

## Map

| Platform | What I owned | Published Terraform |
|----------|----------------|---------------------|
| [cloud.ru / Huawei Cloud](cloud-ru-huawei.md) | Greenfield + brownfield: IAM, VPC, ECS, CCE, RDS, Kafka, OBS | [`../terraform/cloud-ru-huawei/`](../terraform/cloud-ru-huawei/) |
| [AWS](aws.md) | Multi-account / multi-region: VPC, EC2, EKS, RDS, ElastiCache, IAM, S3, CloudFront | [`../terraform/aws/`](../terraform/aws/) |
| [Google Cloud](google-cloud.md) | Project/network bootstrap, compute, GKE-class / VM delivery | Narrative (private trees) |
| [Hetzner](hetzner.md) | Cloud VMs, networking, Linux baseline for app and CI | Narrative (private trees) |
| [OpenStack / Selectel](openstack-selectel.md) | Networks, K8s guests, GitLab, Postgres | [`../terraform/openstack-selectel/`](../terraform/openstack-selectel/) |
| [Proxmox](proxmox.md) | VE guests for K8s, GitLab, Postgres | [`../terraform/proxmox/`](../terraform/proxmox/) |
| [VMware](vmware.md) | VM estates, networking adjacency, guest Linux | Narrative (private trees) |
| [Bare metal](bare-metal.md) | Rack/server Linux, bootstrap, K8s without a hyperscaler | Narrative (private trees) |
| [Cloudflare](cloudflare.md) | DNS as code alongside compute roots | [`../terraform/cloudflare/`](../terraform/cloudflare/) |

```mermaid
flowchart TB
  subgraph cloud [iac/cloud]
    CR[cloud-ru-huawei.md]
    AWS[aws.md]
    OS[openstack-selectel.md]
    PX[proxmox.md]
    CF[cloudflare.md]
    GCP[google-cloud.md]
    HZ[hetzner.md]
    VM[vmware.md]
    BM[bare-metal.md]
  end
  subgraph tf [iac/terraform]
    TFcr[cloud-ru-huawei/]
    TFaws[aws/]
    TFos[openstack-selectel/]
    TFpx[proxmox/]
    TFcf[cloudflare/]
  end
  CR --> TFcr
  AWS --> TFaws
  OS --> TFos
  PX --> TFpx
  CF --> TFcf
  GCP --> Pattern[same ownership pattern]
  HZ --> Pattern
  VM --> Pattern
  BM --> Pattern
```

## How I deliver (every cloud)

1. IAM / project / tenancy baseline
2. VPC or equivalent: subnets, routing, security groups, peering
3. Compute, load balancing, managed DB (tune under load: SQL, locks, replication, sharding — not only create), object storage, messaging (**Kafka**, RabbitMQ, NATS, Artemis, Redis)
4. Kubernetes I stand up and operate: cloud PaaS (EKS/CCE/GKE-class), vanilla, **OpenShift**, **Deckhouse**
5. CI/CD into the cluster: **Jenkins** (plugins, workers; dedicated VMs → Kubernetes) and **GitLab CI + Argo CD** (branch/tag deploys, auto MR, merge rules); Java / .NET / Go / Kotlin / Python / 1C paths; **SonarQube**, **Trivy**, **OSV-Scanner** gates from zero; apps, docs, monitoring handoff
6. Loaded production: multi-zone HA, seamless migrations, ~99.9% SLA, metrics that catch saturation and lag
7. Security from the first apply: OS/IAM hardening, EDR, users and rights, secrets in **Vault** / cloud stores / **ESO** (introduce if missing)
8. Repo and pipeline layout: separate repos (not a dump monorepo), branches that match promotion, folders an auditor and a new engineer can follow
9. On legacy estates: inventory → code or import → runbooks → alerts; add Vault/ESO and hardening if they were never there
10. Incidents including off-hours: Cisco-style 7-step (define → facts → analyze → eliminate → hypothesize → test → document); restore connectivity when a path is blocked; bring downed services back with log-driven isolation

Greenfield: empty project or empty rack → apply.  
Brownfield: inventory → code → `terraform import` → clean `plan`. Same pattern for accelerating delivery, cutting idle spend, and making ops visible.

See case studies: [turnkey from zero](../../case-studies/02-cloud-platform-turnkey.md), [brownfield import](../../case-studies/04-terraform-brownfield-import.md).

Day-2 hosts (Ansible): [`../ansible/`](../ansible/). Positioning: [`../../docs/positioning.md`](../../docs/positioning.md).
