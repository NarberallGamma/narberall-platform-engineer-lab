output "instance_ids" {
  description = "List of instance IDs"
  value       = [for i in sbercloud_compute_instance.this : i.id]
}

output "instance_names" {
  description = "Instance names"
  value       = [for i in sbercloud_compute_instance.this : i.name]
}

output "public_ips" {
  description = "Public IPs"
  value       = [for i in sbercloud_compute_instance.this : i.public_ip]
}

output "network_info" {
  description = "Network information for all instances"
  value = {
    for key, instance in sbercloud_compute_instance.this :
    instance.name => instance.network
  }
}

/*
output "instances_map" {
  description = "Full instance information (map)"
  value       = sbercloud_compute_instance.this
}
*/

output "anti_affinity_group_id" {
  description = "ID of the created anti-affinity group"
  value       = local.anti_affinity_group_id
}
