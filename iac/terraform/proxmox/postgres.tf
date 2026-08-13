resource "proxmox_vm_qemu" "postgres" {
  count = 2

  name        = format("postgres-%02d", count.index + 1)
  target_node = element(["pve-01", "pve-02"], count.index)
  clone       = "ubuntu-22.04-cloud"
  full_clone  = true

  cores  = 4
  memory = 16384

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disk {
    type    = "scsi"
    storage = "local-lvm"
    size    = "100G"
  }

  disk {
    type    = "scsi"
    storage = "local-lvm"
    size    = "500G"
  }

  ciuser    = "ubuntu"
  sshkeys   = var.ssh_public_key
  ipconfig0 = format("ip=10.20.2.%d/24,gw=10.20.0.1", 10 + count.index)
}
