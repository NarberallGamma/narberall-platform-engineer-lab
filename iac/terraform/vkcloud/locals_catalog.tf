# Shortcuts for vm-*.tf
# Example: local.networks.app, local.sg_ids.default, local.flavors.gpu_v100

locals {
  networks     = module.catalog.networks
  flavors      = module.catalog.flavors
  volume_types = module.catalog.volume_types
  az           = module.catalog.az
  sg_ids       = module.catalog.sg_ids
  key_pairs    = module.catalog.key_pairs
}
