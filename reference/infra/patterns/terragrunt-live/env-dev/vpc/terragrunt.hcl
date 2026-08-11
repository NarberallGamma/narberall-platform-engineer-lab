include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_terragrunt_dir()}/../../../_env/vpc.hcl"
  expose = true
}

terraform {
  source = "${include.envcommon.locals.source_base_url}"
}

inputs = {
  vpc_name = "project-a-dev-vpc"
  vpc_cidr = "10.10.0.0/16"
  tags = {
    env     = "dev"
    project = "project-a"
  }
}
