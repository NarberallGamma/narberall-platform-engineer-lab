output "vpc_id" {
  value = sbercloud_vpc.vpc.id
}

output "vpc_status" {
  value = sbercloud_vpc.vpc.status
}

# custom output
output "vpc_cidr" {
  value = var.vpc_cidr
}

