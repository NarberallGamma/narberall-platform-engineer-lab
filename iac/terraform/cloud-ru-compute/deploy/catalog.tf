# Catalog of existing IDs. No sbercloud_vpc / sbercloud_vpc_subnet resources.
# Network and NGFW are managed in a sibling Terragrunt live (live/<env>/<unit>).
module "catalog" {
  source = "./variables"
}
