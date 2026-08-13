# AWS Terraform

Sanitized slices from multi-account / multi-region delivery.

Experience: [`../../cloud/aws.md`](../../cloud/aws.md)

| Path | Role |
|------|------|
| [`root/`](root/) | Standalone Terraform root (VPC, EC2, RDS, ElastiCache, S3, CloudFront, IAM, observability) |
| [`live/`](live/) | Terragrunt live: account → region → env → shared\|services → unit |

Map: [`../RESOURCES.md`](../RESOURCES.md)
