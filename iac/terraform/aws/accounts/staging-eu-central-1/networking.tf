module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "3.19.0"
  name                 = join("-", [var.target_region, "vpc"])
  cidr                 = var.cidr
  azs                  = var.azs
  private_subnets      = var.private_subnets
  enable_dns_hostnames = true
  tags = {
    Terraform = "true"
    Region    = var.target_region
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = module.vpc.vpc_id
  tags   = { Name = join("-", [var.target_region, "igw"]) }
}

resource "aws_route" "default_via_igw" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = element(module.vpc.private_route_table_ids, count.index)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Cross-account / cross-region peering. IDs are fake catalog keys.

resource "aws_vpc_peering_connection" "staging_to_kube" {
  vpc_id      = module.vpc.vpc_id
  peer_vpc_id = "vpc-aaaa0001"
  auto_accept = true
  tags        = { Name = "staging-to-kube" }
}

resource "aws_route" "staging_to_kube" {
  count                     = length(module.vpc.private_route_table_ids)
  route_table_id            = element(module.vpc.private_route_table_ids, count.index)
  destination_cidr_block    = var.kube_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.staging_to_kube.id
}

resource "aws_vpc_peering_connection" "staging_to_prod" {
  vpc_id        = module.vpc.vpc_id
  peer_vpc_id   = "vpc-bbbb0002"
  peer_region   = "ap-southeast-1"
  auto_accept   = false
  tags          = { Name = "staging-to-prod" }
}

resource "aws_route" "staging_to_prod" {
  count                     = length(module.vpc.private_route_table_ids)
  route_table_id            = element(module.vpc.private_route_table_ids, count.index)
  destination_cidr_block    = var.peer_prod_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.staging_to_prod.id
}

resource "aws_vpc_peering_connection" "staging_to_elk" {
  vpc_id      = module.vpc.vpc_id
  peer_vpc_id = "vpc-cccc0003"
  auto_accept = true
  tags        = { Name = "staging-to-elk" }
}

resource "aws_security_group" "default_ops" {
  name        = "eu-central-1-sg"
  description = "SSH and office / VPN"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "office and vpn"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat(var.office_cidrs, var.vpn_cidrs)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "hrm" {
  name   = "hrm-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat(var.office_cidrs, var.vpn_cidrs)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "graph" {
  name   = "graph-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "eks"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.eks_cidr]
  }

  ingress {
    description = "kube"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.kube_cidr]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat(var.office_cidrs, var.vpn_cidrs)
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mysql" {
  name   = "mysql-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = concat(var.office_cidrs, var.vpn_cidrs, [var.kube_cidr, var.eks_cidr, var.cidr])
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sql_proxy" {
  name   = "sql-proxy-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3307
    protocol    = "tcp"
    cidr_blocks = [var.kube_cidr]
  }

  ingress {
    description = "proxy metrics"
    from_port   = 42004
    to_port     = 42004
    protocol    = "tcp"
    cidr_blocks = [var.kube_cidr]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat(var.office_cidrs, var.vpn_cidrs)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "datawh" {
  name   = "datawh-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat(var.office_cidrs, var.vpn_cidrs, [var.cidr, var.kube_cidr, var.peer_prod_cidr])
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.vpn_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "airflow" {
  name   = "airflow-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = concat(var.office_cidrs, var.vpn_cidrs)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
