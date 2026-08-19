# Platform: AWS

Curated resource examples from multi-account / multi-region delivery (not a full client dump).

| File | Resources |
|------|-----------|
| `networking.tf` | VPC module, SG, IGW, routes |
| `nat_keypair.tf` | NAT gateway, EIP, key pair |
| `peering.tf` | VPC peering + routes |
| `compute_gitlab.tf` | GitLab EC2 + EIP + data disk |
| `compute_bastion.tf` | Public bastion + EIP |
| `compute_proxy.tf` | Edge proxy + EIP |
| `compute_runner.tf` | CI runner + data disk |
| `compute_vault.tf` | Vault + encrypted data disk |
| `db.tf` / `modules/db_instance` | EC2-based DB + EBS |
| `mysql_rds.tf` | RDS MySQL HA |
| `elasticache.tf` | Redis replication group |
| `s3.tf` | Bucket, public access block, policy |
| `cloudfront_acm.tf` | ACM + CloudFront OAI/distribution |
| `iam.tf` | Roles, policies, CI user |
| `observability.tf` | SNS, EventBridge, DLM |

Large live layout: [`../live/`](../live/).  
Experience: [`../../../cloud/aws.md`](../../../cloud/aws.md)  
Map: [`../../RESOURCES.md`](../../RESOURCES.md)
