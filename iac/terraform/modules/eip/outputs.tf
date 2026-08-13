output "eip_id" {
  description = "Идентификатор EIP."
  value       = try(sbercloud_vpc_eip.this[0].id, null)
}

output "eip_address" {
  description = "Публичный IP-адрес."
  value       = try(sbercloud_vpc_eip.this[0].address, null)
}

output "eip_ipv6_address" {
  description = "IPv6-адрес (если поддерживается)."
  value       = try(sbercloud_vpc_eip.this[0].ipv6_address, null)
}

output "bandwidth_id" {
  description = "ID полосы пропускания."
  value       = try(sbercloud_vpc_eip.this[0].bandwidth[0].id, null)
}

output "bandwidth_name" {
  description = "Имя полосы пропускания."
  value       = try(sbercloud_vpc_eip.this[0].bandwidth[0].name, null)
}

output "bandwidth_size" {
  description = "Размер полосы пропускания."
  value       = try(sbercloud_vpc_eip.this[0].bandwidth[0].size, null)
}

output "bandwidth_share_type" {
  description = "Тип распределения полосы пропускания."
  value       = try(sbercloud_vpc_eip.this[0].bandwidth[0].share_type, null)
}

output "bandwidth_charge_mode" {
  description = "Режим оплаты полосы пропускания."
  value       = try(sbercloud_vpc_eip.this[0].bandwidth[0].charge_mode, null)
}

output "enterprise_project_id" {
  description = "ID корпоративного проекта."
  value       = try(sbercloud_vpc_eip.this[0].enterprise_project_id, null)
}

output "status" {
  description = "Статус EIP."
  value       = try(sbercloud_vpc_eip.this[0].status, null)
}

# Атрибуты ассоциации (если используется sbercloud_compute_eip_associate)
output "associate_id" {
  description = "Идентификатор ассоциации EIP с инстансом."
  value       = try(sbercloud_compute_eip_associate.this[0].id, null)
}

output "associate_instance_id" {
  description = "ID инстанса, к которому привязан EIP."
  value       = try(sbercloud_compute_eip_associate.this[0].instance_id, null)
}

output "associate_port_id" {
  description = "ID порта, используемого в ассоциации (вычисляется автоматически)."
  value       = try(sbercloud_compute_eip_associate.this[0].port_id, null)
}

output "associate_fixed_ip" {
  description = "Фиксированный IP на интерфейсе инстанса."
  value       = try(sbercloud_compute_eip_associate.this[0].fixed_ip, null)
}
