output "vip_id" {
  description = "ID созданного VIP"
  value       = sbercloud_networking_vip.this.id
}

output "mac_address" {
  description = ""
  value       = sbercloud_networking_vip.this.mac_address
}

output "status" {
    description = ""
    value       = sbercloud_networking_vip.this.status
}

output "device_owner" {
    description = ""
    value       = sbercloud_networking_vip.this.device_owner
}

output "vip_associate_id" {
    description = ""
    value       = sbercloud_networking_vip_associate.this.id
}

output "ip_addresses" {
    description = ""
    value       = sbercloud_networking_vip_associate.this.ip_addresses
}

output "vip_ip_address" {
    description = "The IP address in the subnet for this vip."
    value       = sbercloud_networking_vip_associate.this.vip_ip_address
}

/*
output "vip_ip" {
  description = "IP-адрес VIP"
  value       = sbercloud_networking_vip.this.ip_address
}

output "vip_port_id" {
  description = "ID порта, соответствующего VIP (нужен для привязки EIP)"
  value       = sbercloud_networking_vip.this.port_id
}
*/
