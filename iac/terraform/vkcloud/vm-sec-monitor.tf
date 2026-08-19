# Purpose: security / metrics host (greenfield module, not an imported brownfield VM).
# Private estates used a reusable vkcs module + Terragrunt unit with S3-compatible state.
# Catalog keys only. Documentation CIDR. No live SSH keys in git.

module "sec_monitor" {
  source = "./modules/compute_instance"

  name              = "sec-monitor-01"
  flavor_name       = local.flavors.std_4_8
  os_distro         = "ubuntu"
  os_version        = "24.04"
  availability_zone = local.az.core
  network_id        = local.networks.office
  fixed_ip          = "10.10.1.40"
  security_groups   = ["default"]
  boot_volume_size  = 200
  boot_volume_type  = local.volume_types.high_iops
  ssh_public_keys   = var.sec_monitor_ssh_public_keys
}

variable "sec_monitor_ssh_public_keys" {
  type        = list(string)
  default     = []
  description = "Cloud-init SSH keys for sec-monitor-01. Empty in the public lab."
}
