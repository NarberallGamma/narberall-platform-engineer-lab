locals {
  vpcs          = module.catalog.vpcs
  vpc_cidrs     = module.catalog.vpc_cidrs
  subnets       = module.catalog.subnets
  subnet_cidrs  = module.catalog.subnet_cidrs
  cce_ids       = module.catalog.cce_ids
  rds_ids       = module.catalog.rds_ids
  ecs_ids       = module.catalog.ecs_ids
  do_not_import = module.catalog.do_not_import
  flavors       = module.catalog.flavors
  az            = module.catalog.az
  sg_ids        = module.catalog.sg_ids
  volume_types  = module.catalog.volume_types
  images        = module.catalog.images
  key_pairs     = module.catalog.key_pairs
  ecs_key_pairs = {
    dev     = module.catalog.key_pairs.ecs_dev
    preprod = module.catalog.key_pairs.ecs_preprod
    prod    = module.catalog.key_pairs.ecs_prod
  }
}
