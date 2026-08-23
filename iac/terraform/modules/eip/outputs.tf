output "eip_id" {
  description = "EIP identifier."
  value       = try(sbercloud_vpc_eip.this[0].id, null)
}

output "eip_address" {
  description = "Public IP address."
  value       = try(sbercloud_vpc_eip.this[0].address, null)
}

output "eip_ipv6_address" {
  description = "IPv6 address (when supported)."
  value       = try(sbercloud_vpc_eip.this[0].ipv6_address, null)
}

output "bandwidth_id" {
  description = "Bandwidth ID."
  value       = try(sbercloud_vpc_eip.this[0].bandwidth[0].id, null)
}

output "bandwidth_name" {
  description = "Bandwidth name."
  value       = try(sbercloud_vpc_eip.this[0].bandwidth[0].name, null)
}

output "bandwidth_size" {
  description = "Bandwidth size."
  value       = try(sbercloud_vpc_eip.this[0].bandwidth[0].size, null)
}

output "bandwidth_share_type" {
  description = "Bandwidth share type."
  value       = try(sbercloud_vpc_eip.this[0].bandwidth[0].share_type, null)
}

output "bandwidth_charge_mode" {
  description = "Bandwidth charging mode."
  value       = try(sbercloud_vpc_eip.this[0].bandwidth[0].charge_mode, null)
}

output "enterprise_project_id" {
  description = "Enterprise project ID."
  value       = try(sbercloud_vpc_eip.this[0].enterprise_project_id, null)
}

output "status" {
  description = "EIP status."
  value       = try(sbercloud_vpc_eip.this[0].status, null)
}

# Association attributes (when sbercloud_compute_eip_associate is used)
output "associate_id" {
  description = "Identifier of the EIP-to-instance association."
  value       = try(sbercloud_compute_eip_associate.this[0].id, null)
}

output "associate_instance_id" {
  description = "ID of the instance the EIP is bound to."
  value       = try(sbercloud_compute_eip_associate.this[0].instance_id, null)
}

output "associate_port_id" {
  description = "Port ID used in the association (computed automatically)."
  value       = try(sbercloud_compute_eip_associate.this[0].port_id, null)
}

output "associate_fixed_ip" {
  description = "Fixed IP on the instance interface."
  value       = try(sbercloud_compute_eip_associate.this[0].fixed_ip, null)
}
