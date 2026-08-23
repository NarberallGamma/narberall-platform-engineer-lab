resource "sbercloud_vpc_eip" "this" {
  count = var.create_eip ? 1 : 0

  region                = var.region
  charging_mode         = var.charging_mode
  period                = var.period
  period_unit           = var.period_unit
  auto_renew            = var.auto_renew
  enterprise_project_id = var.enterprise_project_id
  tags                  = var.tags

  publicip {
    type       = var.publicip_type
    ip_address = var.publicip_ip_address
    port_id    = var.publicip_port_id   # bind to a port (for example VIP)
  }

  bandwidth {
    share_type  = var.bandwidth_id != null ? null : var.bandwidth_share_type
    name        = var.bandwidth_name
    size        = var.bandwidth_size
    charge_mode = var.bandwidth_charge_mode
    id          = var.bandwidth_id
  }
}

# Optional association via a separate resource (when binding to an instance rather than a port)
resource "sbercloud_compute_eip_associate" "this" {
  count = var.create_associate && var.create_eip ? 1 : 0

  public_ip   = sbercloud_vpc_eip.this[0].address
  instance_id = var.instance_id
  fixed_ip    = var.fixed_ip
}
