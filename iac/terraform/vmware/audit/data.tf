# Inventory only. Fill org/vdc from tfvars (documentation names in the example).

variable "org_name" { type = string }
variable "org_vdc" { type = string }
variable "edge_name" { type = string }
variable "network_name" { type = string }
variable "storage_policy" { type = string }

data "vcd_storage_profile" "gold" {
  org  = var.org_name
  name = var.storage_policy
}

data "vcd_network_routed_v2" "org_routed" {
  org  = var.org_name
  vdc  = var.org_vdc
  name = var.network_name
}

data "vcd_nsxt_edgegateway" "edge" {
  org  = var.org_name
  vdc  = var.org_vdc
  name = var.edge_name
}

data "vcd_resource_list" "catalogs" {
  name          = "catalogs"
  resource_type = "vcd_catalog"
}

output "storage_iops" {
  value = try(data.vcd_storage_profile.gold.iops_settings[0], null)
}

output "catalogs" {
  value = data.vcd_resource_list.catalogs.list
}
