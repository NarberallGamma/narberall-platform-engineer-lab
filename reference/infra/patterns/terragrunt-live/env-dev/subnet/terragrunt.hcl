include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_terragrunt_dir()}/../../../_env/subnet.hcl"
  expose = true
}

dependency "vpc" {
  config_path = "../vpc"
}

terraform {
  source = "${include.envcommon.locals.source_base_url}"
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
  subnets = {
    app = {
      name              = "project-a-dev-app"
      cidr              = "10.10.1.0/24"
      gateway_ip        = "10.10.1.1"
      availability_zone = "ru-example-1a"
      tags              = { tier = "app" }
    }
  }
}
