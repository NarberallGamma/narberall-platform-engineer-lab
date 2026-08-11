include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../vpc"
}

terraform {
  source = "${get_repo_root()}/terraform/platforms/aws/modules/db_instance"
}

inputs = {
  identifier = "project-a-prod"
  engine     = "postgres"
  subnet_ids = dependency.vpc.outputs.private_subnets
}
