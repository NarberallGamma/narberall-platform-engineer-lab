include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_terragrunt_dir()}/../../../_env/security-group.hcl"
  expose = true
}

terraform {
  source = "${include.envcommon.locals.source_base_url}"
}

inputs = {
  name        = "project-a-dev-default"
  description = "default sg for project-a dev"
  project_name = "project-a-dev"
}
