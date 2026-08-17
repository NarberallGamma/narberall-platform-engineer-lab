# Read-only catalog. No data sources yet (no extra IAM calls on first apply).
# Network remains in sibling Terragrunt live (live/<env>/<unit>).
module "catalog" {
  source = "../deploy/variables"
}
