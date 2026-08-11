resource "sbercloud_networking_vip" "this" {
  name       = var.vip_name
  network_id = var.network_id
  ip_address = var.ip_address
}

resource "sbercloud_networking_vip_associate" "this" {
  vip_id   = sbercloud_networking_vip.this.id
  port_ids = var.port_ids
}
