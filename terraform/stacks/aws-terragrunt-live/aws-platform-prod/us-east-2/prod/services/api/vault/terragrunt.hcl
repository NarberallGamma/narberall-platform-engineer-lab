include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Placeholder unit: per-service Vault / secrets wiring in real trees.
terraform {
  source = "${get_repo_root()}/terraform/stacks/aws-terragrunt-live/modules/noop"
}

inputs = {
  service_name = "api"
}
