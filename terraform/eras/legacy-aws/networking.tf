locals {
  infra_cidr = "10.32.0.0/22"
}

module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  name                 = "project-legacy-a-infra"
  cidr                 = local.infra_cidr
  azs                  = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets      = ["10.32.0.0/24", "10.32.1.0/24", "10.32.2.0/24"]
  enable_dns_hostnames = true
}

resource "aws_security_group" "infra" {
  name        = "project-legacy-a-infra"
  description = "infrastructure sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "allow within vpc"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.infra_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "project-legacy-a-infra" }
}

resource "aws_internet_gateway" "infra" {
  vpc_id = module.vpc.vpc_id
  tags   = { Name = "project-legacy-a-igw" }
}

resource "aws_route" "default_via_igw" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = element(module.vpc.private_route_table_ids, count.index)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.infra.id
}
