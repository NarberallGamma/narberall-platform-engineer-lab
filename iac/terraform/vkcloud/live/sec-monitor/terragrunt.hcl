include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules//compute_instance"
}

inputs = {
  name              = "sec-monitor-01"
  flavor_name       = "STD3-4-8"
  os_distro         = "ubuntu"
  os_version        = "24.04"
  network_id        = "00000000-0000-4000-8000-000000000001"
  fixed_ip          = "10.10.1.40"
  security_groups   = ["default"]
  boot_volume_size  = 200
  ssh_public_keys   = []
  availability_zone = null
}
