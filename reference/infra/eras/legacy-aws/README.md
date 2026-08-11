# Era: legacy AWS (Flant-era client style)

Typical patterns from earlier AWS client delivery:

- `terraform-aws-modules/vpc/aws` for network
- EC2 + EIP + EBS with `lifecycle.ignore_changes` on `user_data` / `ami`
- Small reusable `modules/db_instance`
- S3 remote state + named AWS profile

Names and CIDRs are sanitized. Original client identifiers are not present.
