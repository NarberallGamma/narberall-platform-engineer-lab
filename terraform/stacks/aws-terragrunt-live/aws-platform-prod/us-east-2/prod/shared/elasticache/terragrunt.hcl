include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../vpc"
}

terraform {
  source = "${get_repo_root()}/terraform/stacks/aws-terragrunt-live/modules/elasticache"
}

inputs = {
  name       = "project-a-redis"
  subnet_ids = dependency.vpc.outputs.private_subnets
  vpc_id     = dependency.vpc.outputs.vpc_id
}
