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

output "dns_private_dev_zone_id" {
  description = "Private DNS zone on the dev VPC (RECURSIVE)"
  value       = sbercloud_dns_zone.example_com_private_dev.id
}

output "dns_private_dev_recordset_ids" {
  description = "A record set IDs in the private dev zone (registry/git/vault)"
  value       = { for k, rs in sbercloud_dns_recordset.example_com_private_dev_a : k => rs.id }
}
