# VM from catalog template (Ubuntu-24.04) or empty + ISO.
# Extra gold disks: vcd_vm_internal_disk (unit 1/2).
#
# Docs: https://registry.terraform.io/providers/vmware/vcd/latest/docs/resources/vapp_vm

resource "vcd_vapp_vm" "this" {
  org = var.org_name
  vdc = var.org_vdc

  vapp_name     = var.vapp_name
  name          = var.vm_name
  computer_name = var.computer_name

  memory    = var.memory_mb
  cpus      = var.cpus
  cpu_cores = var.cpu_cores

  vapp_template_id = var.vapp_template_id
  os_type          = var.vapp_template_id == null ? var.os_type : null
  hardware_version = var.vapp_template_id == null ? var.hardware_version : null
  firmware         = var.vapp_template_id == null ? var.firmware : null
  boot_image_id    = var.vapp_template_id == null ? var.boot_image_id : null
  storage_profile  = var.storage_policy
  power_on         = var.power_on

  dynamic "boot_options" {
    for_each = var.vapp_template_id == null ? [1] : []
    content {
      efi_secure_boot = var.efi_secure_boot
    }
  }

  dynamic "override_template_disk" {
    for_each = var.vapp_template_id != null ? [1] : []
    content {
      bus_type        = "paravirtual"
      size_in_mb      = var.disks.os_gb * 1024
      bus_number      = 0
      unit_number     = 0
      iops            = var.disk_iops.os
      storage_profile = var.storage_policy
    }
  }

  network {
    type               = "org"
    name               = var.network_name
    adapter_type       = "VMXNET3"
    ip_allocation_mode = var.ip_allocation_mode
    ip                 = var.ip_allocation_mode == "MANUAL" ? var.ip_address : ""
    is_primary         = true
  }

  customization {
    enabled                    = var.guest_customization_enabled
    allow_local_admin_password = var.admin_password != null && var.admin_password != ""
    auto_generate_password     = false
    admin_password             = var.admin_password
    initscript                 = var.guest_initscript
  }
}

# Extra disks reboot the VM (allow_vm_reboot). Wait until Guest
# Customization + initscript postcustomization finish, otherwise ens* stays DOWN.
resource "time_sleep" "after_vm_before_extra_disks" {
  depends_on      = [vcd_vapp_vm.this]
  create_duration = var.extra_disk_delay
}

resource "vcd_vm_internal_disk" "data" {
  depends_on = [time_sleep.after_vm_before_extra_disks]

  org = var.org_name
  vdc = var.org_vdc

  vapp_name       = var.vapp_name
  vm_name         = vcd_vapp_vm.this.name
  bus_type        = "paravirtual"
  bus_number      = 0
  unit_number     = 1
  size_in_mb      = var.disks.data_gb * 1024
  iops            = var.disk_iops.data
  storage_profile = var.storage_policy
  allow_vm_reboot = true
}

resource "vcd_vm_internal_disk" "wal" {
  depends_on = [time_sleep.after_vm_before_extra_disks]

  org = var.org_name
  vdc = var.org_vdc

  vapp_name       = var.vapp_name
  vm_name         = vcd_vapp_vm.this.name
  bus_type        = "paravirtual"
  bus_number      = 0
  unit_number     = 2
  size_in_mb      = var.disks.wal_gb * 1024
  iops            = var.disk_iops.wal
  storage_profile = var.storage_policy
  allow_vm_reboot = true
}
