include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "eks" {
  config_path = "../eks"
}

terraform {
  source = "${get_repo_root()}/iac/terraform/aws/live/modules/noop"
}

inputs = {
  service_name = "eks-karpenter"
}
