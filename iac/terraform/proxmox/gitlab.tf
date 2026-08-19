resource "proxmox_vm_qemu" "gitlab" {
  name        = "gitlab-01"
  target_node = "pve-01"
  clone       = "ubuntu-22.04-cloud"
  full_clone  = true

  cores  = 8
  memory = 16384

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disk {
    type    = "scsi"
    storage = "local-lvm"
    size    = "80G"
  }

  disk {
    type    = "scsi"
    storage = "local-lvm"
    size    = "200G"
  }

  ciuser    = "ubuntu"
  sshkeys   = var.ssh_public_key
  ipconfig0 = "ip=10.20.3.10/24,gw=10.20.0.1"

  lifecycle {
    ignore_changes = [network, disk]
  }
}
