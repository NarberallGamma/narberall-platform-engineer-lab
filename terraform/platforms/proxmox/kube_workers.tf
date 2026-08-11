resource "proxmox_vm_qemu" "kube_worker_prod" {
  count = 3

  name        = format("kube-worker-prod-%02d", count.index + 1)
  target_node = element(["pve-01", "pve-02", "pve-03"], count.index)
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
    size    = "200G"
  }

  ciuser    = "ubuntu"
  sshkeys   = var.ssh_public_key
  ipconfig0 = format("ip=10.20.1.%d/24,gw=10.20.0.1", 20 + count.index)
}

resource "proxmox_vm_qemu" "gitlab" {
  name        = "gitlab"
  target_node = "pve-02"
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
    size    = "300G"
  }

  ciuser    = "ubuntu"
  sshkeys   = var.ssh_public_key
  ipconfig0 = "ip=10.20.0.50/24,gw=10.20.0.1"
}
