variable "name" {
  type        = string
  description = "Instance name"
}

variable "flavor_name" {
  type        = string
  description = "VK Cloud flavor name, for example STD3-4-8"
}

variable "os_distro" {
  type    = string
  default = "ubuntu"
}

variable "os_version" {
  type        = string
  description = "mcs_os_version, for example 24.04"
}

variable "availability_zone" {
  type    = string
  default = null
}

variable "key_pair" {
  type        = string
  default     = null
  description = "Optional Nova keypair. Prefer ssh_public_keys via cloud-init."
}

variable "ssh_public_keys" {
  type        = list(string)
  default     = []
  description = "Public SSH keys for the default user (cloud-init user_data)"
}

variable "network_id" {
  type        = string
  description = "Neutron network UUID"
}

variable "fixed_ip" {
  type        = string
  default     = null
  description = "Static IPv4 so Ansible inventory does not drift"
}

variable "security_groups" {
  type    = list(string)
  default = ["default"]
}

variable "boot_volume_size" {
  type    = number
  default = 50
}

variable "boot_volume_type" {
  type    = string
  default = "ceph-ssd"
}
