resource "proxmox_vm_qemu" "ci_runner" {
  count = 2

  name        = format("ci-runner-%02d", count.index + 1)
  target_node = element(["pve-01", "pve-02"], count.index)
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
    size    = "80G"
  }

  ciuser    = "ubuntu"
  sshkeys   = var.ssh_public_key
  ipconfig0 = format("ip=10.20.3.%d/24,gw=10.20.0.1", 20 + count.index)

  lifecycle {
    ignore_changes = [network, disk]
  }
}
