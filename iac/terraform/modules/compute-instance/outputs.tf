output "instance_ids" {
  description = "Список ID инстансов"
  value       = [for i in sbercloud_compute_instance.this : i.id]
}

output "instance_names" {
  description = "Имена инстансов"
  value       = [for i in sbercloud_compute_instance.this : i.name]
}

output "public_ips" {
  description = "Публичные IP"
  value       = [for i in sbercloud_compute_instance.this : i.public_ip]
}

output "network_info" {
  description = "Сетевая информация всех инстансов"
  value = {
    for key, instance in sbercloud_compute_instance.this :
    instance.name => instance.network
  }
}

/*
output "instances_map" {
  description = "Полная информация по инстансам (map)"
  value       = sbercloud_compute_instance.this
}
*/

output "anti_affinity_group_id" {
  description = "ID созданной anti-affinity группы"
  value       = local.anti_affinity_group_id
}
