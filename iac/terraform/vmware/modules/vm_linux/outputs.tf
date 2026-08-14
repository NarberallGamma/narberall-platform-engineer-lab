output "vm_name" {
  value = vcd_vapp_vm.this.name
}

output "computer_name" {
  value = vcd_vapp_vm.this.computer_name
}

output "cpu" {
  value = {
    cpus      = var.cpus
    cpu_cores = var.cpu_cores
    sockets   = var.cpus / var.cpu_cores
  }
}

output "disks" {
  value = {
    policy = var.storage_policy
    os = {
      size_gb = var.disks.os_gb
      iops    = var.disk_iops.os
    }
    data = {
      size_gb = var.disks.data_gb
      iops    = vcd_vm_internal_disk.data.iops
    }
    wal = {
      size_gb = var.disks.wal_gb
      iops    = vcd_vm_internal_disk.wal.iops
    }
  }
}
