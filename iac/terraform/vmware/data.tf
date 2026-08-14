# Read-only inventory. Works with create_vm=false (token and IOPS check).

data "vcd_storage_profile" "gold" {
  org  = var.org_name
  name = local.storage.policy
}

data "vcd_network_routed_v2" "org_routed" {
  org  = var.org_name
  vdc  = var.org_vdc
  name = local.networks.org_routed
}

data "vcd_nsxt_edgegateway" "edge" {
  org  = var.org_name
  vdc  = var.org_vdc
  name = local.edge_name
}

data "vcd_resource_list" "catalogs" {
  name          = "catalogs"
  resource_type = "vcd_catalog"
}

data "vcd_catalog" "ubuntu" {
  count = local.ubuntu_iso.catalog_name != "" ? 1 : 0
  org   = local.ubuntu_iso.catalog_org != "" ? local.ubuntu_iso.catalog_org : var.org_name
  name  = local.ubuntu_iso.catalog_name
}

data "vcd_catalog_vapp_template" "ubuntu_24_04" {
  count      = local.ubuntu_iso.catalog_name != "" ? 1 : 0
  org        = local.ubuntu_iso.catalog_org
  catalog_id = data.vcd_catalog.ubuntu[0].id
  name       = "Ubuntu-24.04"
}

locals {
  gold_iops = try(data.vcd_storage_profile.gold.iops_settings[0], null)

  iops_per_gb = local.gold_iops != null ? local.gold_iops.disk_iops_per_gb_max : local.storage.iops_per_gb_max
  iops_max    = local.gold_iops != null ? local.gold_iops.maximum_disk_iops : local.storage.maximum_disk_iops

  ubuntu_24_04_template_id = local.ubuntu_iso.catalog_name != "" ? data.vcd_catalog_vapp_template.ubuntu_24_04[0].id : null
}
