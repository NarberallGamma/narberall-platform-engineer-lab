resource "proxmox_vm_qemu" "gitlab" {
  name        = "gitlab"
  desc        = "Ubuntu gitlab"
  target_node = var.hv_nodes[2]
  clone       = var.clone_template
  full_clone  = true
  onboot      = true
  agent       = 1
  scsihw      = "virtio-scsi-pci"
  qemu_os     = "l26"
  cores       = 4
  memory      = 16384
  balloon     = 0
  os_type     = "cloud-init"
  sshkeys     = var.ssh_public_key
  ipconfig0   = "ip=10.20.22.47/24,gw=10.20.22.1"
  ipconfig1   = "ip=203.0.113.20/28,gw=203.0.113.17"

  network {
    bridge = "vmbr0"
    model  = "virtio"
  }

  network {
    bridge = "vmbr1"
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
          size      = "100"
          replicate = true
          storage   = var.storage
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [disks]
  }
}

resource "proxmox_vm_qemu" "gitlab_runner" {
  name        = "gitlab-runner"
  desc        = "Ubuntu gitlab-runner"
  target_node = var.hv_nodes[2]
  clone       = var.clone_template
  full_clone  = true
  onboot      = true
  agent       = 1
  scsihw      = "virtio-scsi-pci"
  qemu_os     = "l26"
  cores       = 4
  memory      = 8192
  balloon     = 0
  os_type     = "cloud-init"
  sshkeys     = var.ssh_public_key
  ipconfig0   = "ip=10.20.22.48/24,gw=10.20.22.1"

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
          size      = "50"
          replicate = true
          storage   = var.storage
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [disks]
  }
}

resource "proxmox_vm_qemu" "vpn" {
  name        = "vpn"
  desc        = "Ubuntu vpn"
  target_node = var.hv_nodes[1]
  clone       = var.clone_template
  full_clone  = true
  onboot      = true
  agent       = 1
  scsihw      = "virtio-scsi-pci"
  qemu_os     = "l26"
  cores       = 2
  memory      = 2048
  balloon     = 0
  os_type     = "cloud-init"
  sshkeys     = var.ssh_public_key
  ipconfig0   = "ip=10.20.22.147/24"
  ipconfig1   = "ip=203.0.113.21/28,gw=203.0.113.17"

  network {
    bridge = "vmbr0"
    model  = "virtio"
  }

  network {
    bridge = "vmbr1"
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
          size      = "30"
          replicate = true
          storage   = var.storage
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [disks]
  }
}
