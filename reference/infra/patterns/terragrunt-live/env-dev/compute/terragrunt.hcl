include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_terragrunt_dir()}/../../../_env/compute.hcl"
  expose = true
}

dependency "subnet" {
  config_path = "../subnet"
}

dependency "sg" {
  config_path = "../security-group"
}

terraform {
  source = "${include.envcommon.locals.source_base_url}"
}

inputs = {
  instance_name = "project-a-dev-app"
  flavor_id     = "s7n.large.2"
  image_name    = "Ubuntu 24.04 server 64bit"
  instance_count = 2
  availability_zones = ["ru-example-1a", "ru-example-1b"]
  security_group_ids = [dependency.sg.outputs.id]
  networks = [
    {
      uuid = values(dependency.subnet.outputs.subnet_ids)[0]
    }
  ]
  system_disk_type = "SSD"
  system_disk_size = 40
}
