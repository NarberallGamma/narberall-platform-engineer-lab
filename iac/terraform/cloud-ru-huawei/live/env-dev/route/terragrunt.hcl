include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_terragrunt_dir()}/../../../_env/route.hcl"
  expose = true
}

dependency "vpc" {
  config_path = "../vpc"
}

terraform {
  source = "${include.envcommon.locals.source_base_url}"
}

inputs = {
  vpc_id      = dependency.vpc.outputs.vpc_id
  destination = "0.0.0.0/0"
  type        = "nat"
  nexthop     = "nat-gateway-id-example"
  description = "default egress via NAT (example)"
}
