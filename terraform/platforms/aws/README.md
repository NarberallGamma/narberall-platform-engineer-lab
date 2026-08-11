# Platform: AWS

Terraform patterns from multi-account / multi-region AWS delivery:

- VPC via `terraform-aws-modules/vpc/aws`
- EC2 + EIP + EBS with `lifecycle.ignore_changes` on `user_data` / `ami`
- RDS MySQL (`mysql_rds.tf`)
- Small reusable `modules/db_instance`
- S3 remote state + named AWS profile

Private trees also contained dozens of regional roots (compute, MySQL, networking). This folder is a curated slice, not a full client dump.

For large Terragrunt AWS live (EKS, Karpenter, Vault, RDS shared layers) see [`../../stacks/aws-terragrunt-live/`](../../stacks/aws-terragrunt-live/).
