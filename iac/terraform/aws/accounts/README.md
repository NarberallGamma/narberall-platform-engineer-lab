# Multi-account AWS roots

Private delivery used one Terraform root per **account + region** (`account-<env>-<region>/`), plus a shared AMI module and a CloudWatch Events fan-in for sensitive API calls.

This lab is a **curated slice** of that layout (two compute accounts, one edge/WAF account, one DWH account). Full private trees stay out.

| Path | Account role | What is in code |
|------|--------------|-----------------|
| [`staging-eu-central-1/`](staging-eu-central-1/) | Staging compute | VPC, peering, GitLab, proxies, backup+st1, kube workers, self-managed MySQL, DWH MySQL/PG, DLM, CloudFront |
| [`prod-ap-southeast-1/`](prod-ap-southeast-1/) | Production compute | Bastion, Windows reports host, graph DB pair, SQL proxy, backup, kube workers, WordPress-class, MySQL primary/replica + binlogs |
| [`edge-us-east-1/`](edge-us-east-1/) | Global edge | ACM for `*.staging.k8s.example.com`, WAFv2 allow-list for CloudFront |
| [`dwh-us-east-2/`](dwh-us-east-2/) | Analytics | Self-managed Postgres on io1 (1.3 TiB data disks) |
| [`modules/common/`](modules/common/) | Shared | Ubuntu 20/22/24 + ARM + Windows Server AMI lookups |
| [`modules/sensitive-events/`](modules/sensitive-events/) | Shared | EventBridge patterns + SNS for IAM/S3/EC2 sensitive calls |

Documentation CIDRs (`10.10.x.x`, `203.0.113.x`). No account IDs, no live VPC/SG/pcx IDs, no office VPN lists.

Standalone single-root samples stay in [`../root/`](../root/). Terragrunt live: [`../live/`](../live/).
