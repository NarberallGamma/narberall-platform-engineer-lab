output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value       = { for k, subnet in sbercloud_vpc_subnet.this : k => subnet.id }
}

output "subnet_attributes" {
  description = "Map of subnet names to all attributes"
  value       = sbercloud_vpc_subnet.this
}
