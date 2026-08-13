resource "aws_vpc_peering_connection" "app_to_data" {
  vpc_id      = module.vpc.vpc_id
  peer_vpc_id = var.peer_vpc_id
  auto_accept = true

  tags = {
    Name = "project-a-app-to-data"
  }
}

variable "peer_vpc_id" {
  type = string
}

resource "aws_route" "to_peer" {
  route_table_id            = module.vpc.private_route_table_ids[0]
  destination_cidr_block    = var.peer_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.app_to_data.id
}

variable "peer_cidr" {
  type    = string
  default = "10.50.0.0/16"
}
