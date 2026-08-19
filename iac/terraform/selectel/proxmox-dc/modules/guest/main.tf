locals {
  lan_prefix = cidrhost(var.lan_cidr, 0)
  lan_octets = split(".", local.lan_prefix)
  lan_base   = format("%s.%s.%s", local.lan_octets[0], local.lan_octets[1], local.lan_octets[2])
}

resource "proxmox_vm_qemu" "this" {
  count = var.count_vms

  name        = format("%s-%02d", var.name_prefix, count.index + 1)
  desc        = var.desc
  target_node = var.hv_nodes[count.index % length(var.hv_nodes)]
  clone       = var.clone_template
  full_clone  = true
  onboot      = true
  vm_state    = "running"
  agent       = 1
  scsihw      = "virtio-scsi-pci"
  qemu_os     = "l26"
  cores       = var.cores
  memory      = var.memory
  balloon     = 0
  os_type     = "cloud-init"
  sshkeys     = var.ssh_public_key
  ipconfig0 = format("ip=%s.%d/24,gw=%s", local.lan_base, var.lan_ip_start + count.index, var.lan_gw)

  network {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disks {
    ide {
      ide3 {
        cloudinit {
          storage = var.storage
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size      = tostring(var.disk_gb)
          replicate = true
          storage   = var.storage
        }
      }
      dynamic "scsi1" {
        for_each = var.extra_disk_gb > 0 ? [1] : []
        content {
          disk {
            size      = tostring(var.extra_disk_gb)
            replicate = true
            storage   = var.storage
          }
        }
      }
      dynamic "scsi2" {
        for_each = var.extra_disk2_gb > 0 ? [1] : []
        content {
          disk {
            size      = tostring(var.extra_disk2_gb)
            replicate = true
            storage   = var.storage
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [ipconfig0, disks]
  }
}

output "names" {
  value = proxmox_vm_qemu.this[*].name
}
