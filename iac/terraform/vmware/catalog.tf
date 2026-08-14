# Catalog maps (networks, storage, template). Same pattern as vkcloud/.

module "catalog" {
  source     = "./variables"
  ubuntu_iso = var.ubuntu_iso
}
