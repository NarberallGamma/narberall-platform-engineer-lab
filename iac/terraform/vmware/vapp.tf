resource "vcd_vapp" "db_pg_01" {
  count = var.create_vm ? 1 : 0

  name        = "db-pg-01"
  description = "DB-class guest: Ubuntu-24.04 template, gold OS / data / WAL disks"
  power_on    = true
}

resource "vcd_vapp_org_network" "org_routed" {
  count = var.create_vm ? 1 : 0

  vapp_name        = vcd_vapp.db_pg_01[0].name
  org_network_name = local.networks.org_routed
}
