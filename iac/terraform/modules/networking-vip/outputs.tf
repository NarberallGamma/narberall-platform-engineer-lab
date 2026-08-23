output "vip_id" {
  description = "ID of the created VIP"
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
  description = "VIP IP address"
  value       = sbercloud_networking_vip.this.ip_address
}

output "vip_port_id" {
  description = "Port ID that corresponds to the VIP (needed to attach an EIP)"
  value       = sbercloud_networking_vip.this.port_id
}
*/
