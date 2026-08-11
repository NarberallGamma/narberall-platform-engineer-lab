resource "sbercloud_networking_secgroup_rule" "this" {
  for_each = { for rule in var.rules : rule.name => rule }

  security_group_id = var.security_group_id
  region            = each.value.region
  direction         = each.value.direction
  ethertype         = each.value.ethertype
  description       = each.value.description
  protocol          = each.value.protocol
  ports             = lookup(each.value, "ports", null)
  port_range_min    = lookup(each.value, "port_range_min", null)
  port_range_max    = lookup(each.value, "port_range_max", null)
  remote_ip_prefix  = lookup(each.value, "remote_ip_prefix", null)
  remote_group_id   = lookup(each.value, "remote_group_id", null)
  action            = each.value.action
  priority          = each.value.priority
}
