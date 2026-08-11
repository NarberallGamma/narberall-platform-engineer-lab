resource "sbercloud_vpc_route_table" "this" {
  region  = var.region
  vpc_id  = var.vpc_id
  name    = var.name
  description = var.description
  subnets = var.subnets  #data.sbercloud_vpc_subnet_ids.subnet_ids.ids

  dynamic "route" {
    for_each = var.routes
    content {
      destination = route.value.destination
      type        = route.value.type
      nexthop     = route.value.nexthop
      description = route.value.description 
    }
  }
}

