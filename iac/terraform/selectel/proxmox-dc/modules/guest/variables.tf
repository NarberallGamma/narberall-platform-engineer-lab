variable "name_prefix" { type = string }
variable "count_vms" { type = number }
variable "hv_nodes" { type = list(string) }
variable "clone_template" { type = string }
variable "storage" { type = string }
variable "ssh_public_key" { type = string }
variable "desc" { type = string }
variable "cores" { type = number }
variable "memory" { type = number }
variable "disk_gb" { type = number }
variable "extra_disk_gb" {
  type    = number
  default = 0
}
variable "extra_disk2_gb" {
  type    = number
  default = 0
}
variable "lan_ip_start" { type = number }
variable "lan_cidr" {
  type    = string
  default = "10.20.22.0/24"
}
variable "lan_gw" {
  type    = string
  default = "10.20.22.1"
}
