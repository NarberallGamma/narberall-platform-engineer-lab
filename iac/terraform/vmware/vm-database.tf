# Computer Name: lowercase, <=15 (VCD limit).

locals {
  vm_db_pg_01_disks = {
    os_gb   = 40
    data_gb = 100
    wal_gb  = 100
  }
  vm_db_pg_01_iops = {
    os   = min(local.vm_db_pg_01_disks.os_gb * local.iops_per_gb, local.iops_max)
    data = min(local.vm_db_pg_01_disks.data_gb * local.iops_per_gb, local.iops_max)
    wal  = min(local.vm_db_pg_01_disks.wal_gb * local.iops_per_gb, local.iops_max)
  }

  # Documentation CIDR. Gateway .1 is reserved.
  vm_db_pg_01_nic = {
    adapter_type       = "VMXNET3"
    ip_allocation_mode = "MANUAL"
    ip_address         = "10.10.50.10"
  }
}

module "vm_db_pg_01" {
  count  = var.create_vm ? 1 : 0
  source = "./modules/vm_linux"

  org_name = var.org_name
  org_vdc  = var.org_vdc

  vapp_name     = vcd_vapp.db_pg_01[0].name
  vm_name       = "db-pg-01"
  computer_name = "db-pg-01"

  cpus      = 8
  cpu_cores = 8
  memory_mb = 32768

  power_on = true

  storage_policy = local.storage.policy
  disk_iops      = local.vm_db_pg_01_iops
  disks          = local.vm_db_pg_01_disks

  network_name       = vcd_vapp_org_network.org_routed[0].org_network_name
  ip_allocation_mode = local.vm_db_pg_01_nic.ip_allocation_mode
  ip_address         = local.vm_db_pg_01_nic.ip_address

  vapp_template_id = local.ubuntu_24_04_template_id

  guest_customization_enabled = true
  admin_password              = local.guest_pw_root
  extra_disk_delay            = "60s"
  guest_initscript            = local.guest_initscript
}
