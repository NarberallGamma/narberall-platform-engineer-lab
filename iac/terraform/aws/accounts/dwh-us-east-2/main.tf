module "common" {
  source = "../modules/common"
}

module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "3.19.0"
  name                 = "us-east-2-vpc"
  cidr                 = var.cidr
  azs                  = var.azs
  private_subnets      = var.private_subnets
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "this" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_route" "default_via_igw" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = element(module.vpc.private_route_table_ids, count.index)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_vpc_peering_connection" "dwh_to_staging" {
  vpc_id      = module.vpc.vpc_id
  peer_vpc_id = "vpc-aaaa0001"
  peer_region = "eu-central-1"
  auto_accept = false
  tags        = { Name = "dwh-to-staging" }
}

resource "aws_route" "dwh_to_staging" {
  count                     = length(module.vpc.private_route_table_ids)
  route_table_id            = element(module.vpc.private_route_table_ids, count.index)
  destination_cidr_block    = var.peer_staging_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.dwh_to_staging.id
}

resource "aws_security_group" "postgres" {
  name   = "postgres-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = concat(var.office_cidrs, [var.peer_staging_cidr])
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "analytics_pg" {
  ami                         = module.common.ubuntu_22_ami
  instance_type               = "r5.xlarge"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.postgres.id]
  associate_public_ip_address = true
  ebs_optimized               = true
  key_name                    = var.key_name
  user_data                   = templatefile("${path.module}/../templates/init.tmpl", { vm_name = "analytics-pg" })

  tags = {
    Name    = "analytics-pg"
    Service = "postgres"
    Group   = "dwh"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }
}

resource "aws_ebs_volume" "analytics_pg_data" {
  availability_zone = "us-east-2a"
  size              = 1300
  type              = "io1"
  iops              = 4000
  tags              = { Name = "analytics-pg-data" }
}

resource "aws_volume_attachment" "analytics_pg_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.analytics_pg_data.id
  instance_id = aws_instance.analytics_pg.id
}

resource "aws_eip" "analytics_pg" {
  instance   = aws_instance.analytics_pg.id
  depends_on = [aws_instance.analytics_pg]
}
