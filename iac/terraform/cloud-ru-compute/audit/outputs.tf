output "backend_key" {
  description = "OBS object for this stack; must stay outside live/"
  value       = "platform/audit/terraform.tfstate"
}

output "network_source_of_truth" {
  description = "Sibling Terragrunt live that owns VPC, subnet, peering, EIP, VIP, NGFW"
  value       = "live/<env>/<unit>/terraform.tfstate"
}

output "vpcs" {
  value = module.catalog.vpcs
}

output "subnets" {
  value = module.catalog.subnets
}

output "cce_ids" {
  value = module.catalog.cce_ids
}

output "rds_ids" {
  value = module.catalog.rds_ids
}

output "ecs_ids" {
  value = module.catalog.ecs_ids
}

output "do_not_import" {
  value = module.catalog.do_not_import
}
