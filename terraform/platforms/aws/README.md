# Platform: AWS

Terraform patterns from AWS client delivery (names and CIDRs sanitized):

- `terraform-aws-modules/vpc/aws` for network
- EC2 + EIP + EBS with `lifecycle.ignore_changes` on `user_data` / `ami`
- Small reusable `modules/db_instance`
- S3 remote state + named AWS profile

This is active career experience, published as a clean sample tree for portfolio readers.
