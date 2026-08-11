output "id" {
  description = "The route ID, the format is <route_table_id>/<destination>"
  value       = sbercloud_vpc_route.this.id
}

output "route_table_name" {
  description = "The name of route table."
  value       = sbercloud_vpc_route.this.route_table_name
}

