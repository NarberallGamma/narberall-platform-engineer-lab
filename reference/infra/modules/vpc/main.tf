terraform {
  # This module is now only being tested with Terraform v1.13.3. 
  required_version = ">= 1.13.3"
}

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

