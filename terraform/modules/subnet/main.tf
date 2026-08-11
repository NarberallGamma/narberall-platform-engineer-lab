resource "sbercloud_vpc_subnet" "this" {
  for_each = var.subnets

  vpc_id            = var.vpc_id
  cidr              = each.value.cidr
  gateway_ip        = each.value.gateway_ip
  availability_zone = each.value.availability_zone
  name              = each.value.name != null ? each.value.name : each.key

  tags = each.value.tags
  # при необходимости добавьте другие атрибуты (dhcp_lease_time и т.п.)
}
