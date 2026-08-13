resource "proxmox_vm_qemu" "kube_master" {
  count = 3

  name        = format("kube-master-%02d", count.index + 1)
  target_node = "pve-01"
  clone       = "ubuntu-22.04-cloud"
  full_clone  = true

  cores   = 4
  sockets = 1
  memory  = 8192

  agent = 1

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disk {
    type    = "scsi"
    storage = "local-lvm"
    size    = "80G"
  }

  ciuser     = "ubuntu"
  sshkeys    = var.ssh_public_key
  ipconfig0  = format("ip=10.20.0.%d/24,gw=10.20.0.1", 10 + count.index)

  lifecycle {
    ignore_changes = [network, disk]
  }
}
