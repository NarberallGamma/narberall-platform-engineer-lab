resource "proxmox_vm_qemu" "monitor" {
  name        = "monitor-01"
  target_node = "pve-02"
  clone       = "ubuntu-22.04-cloud"
  full_clone  = true

  cores  = 4
  memory = 8192

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disk {
    type    = "scsi"
    storage = "local-lvm"
    size    = "200G"
  }

  ciuser    = "ubuntu"
  sshkeys   = var.ssh_public_key
  ipconfig0 = "ip=10.20.3.40/24,gw=10.20.0.1"

  lifecycle {
    ignore_changes = [network, disk]
  }
}
