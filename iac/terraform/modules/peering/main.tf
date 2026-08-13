resource "sbercloud_vpc_peering_connection" "this" {
  region         = var.region
  name           = var.name
  vpc_id         = var.local_vpc_id
  peer_vpc_id    = var.peer_vpc_id
  peer_tenant_id = var.peer_tenant_id 
}

