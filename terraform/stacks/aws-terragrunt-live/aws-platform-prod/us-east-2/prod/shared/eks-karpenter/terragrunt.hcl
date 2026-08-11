include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "eks" {
  config_path = "../eks"
}

terraform {
  source = "${get_repo_root()}/terraform/stacks/aws-terragrunt-live/modules/noop"
}

inputs = {
  service_name = "eks-karpenter"
}
