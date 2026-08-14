locals {
  networks      = module.catalog.networks
  network_cidrs = module.catalog.network_cidrs
  network_gw    = module.catalog.network_gw
  storage       = module.catalog.storage
  ubuntu_iso    = module.catalog.ubuntu_iso
  edge_name     = module.catalog.edge_name
}
