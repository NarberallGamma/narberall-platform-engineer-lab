resource "sbercloud_vpc" "vpc" {
  name = var.vpc_name
  cidr = var.vpc_cidr
  region = var.region
  description = var.description
  enterprise_project_id = var.enterprise_project_id
  tags = merge(
    {
      managed = "managed by terraform"
    },
    var.tags
  )
}

