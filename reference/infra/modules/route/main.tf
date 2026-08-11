resource "sbercloud_vpc_route" "this" {
  region      = var.region
  vpc_id      = var.vpc_id
  destination = var.destination
  type        = var.type  
  nexthop     = var.nexthop
  description = var.description
  route_table_id = var.route_table_id 
}

