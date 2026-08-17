output "backend_key" {
  description = "OBS object for this stack; must stay outside live/"
  value       = "platform/deploy/terraform.tfstate"
}

output "network_source_of_truth" {
  description = "Sibling Terragrunt live that owns VPC, subnet, peering, EIP, VIP, NGFW"
  value       = "live/<env>/<unit>/terraform.tfstate"
}

output "vpcs" {
  value = local.vpcs
}

output "subnets" {
  value = local.subnets
}

output "cce_ids" {
  value = local.cce_ids
}

output "rds_ids" {
  value = local.rds_ids
}

output "ecs_ids" {
  value = local.ecs_ids
}

output "do_not_import" {
  description = "Resources already in live/*. Do not declare as resource here."
  value       = local.do_not_import
}
