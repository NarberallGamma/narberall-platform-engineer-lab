locals {
  infra_cidr = "10.32.0.0/22"
}

module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  name                 = "project-a-infra"
  cidr                 = local.infra_cidr
  azs                  = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets      = ["10.32.0.0/24", "10.32.1.0/24", "10.32.2.0/24"]
  public_subnets       = ["10.32.100.0/24", "10.32.101.0/24", "10.32.102.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
}

resource "aws_security_group" "infra" {
  name        = "project-a-infra"
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

  tags = { Name = "project-a-infra" }
}

resource "aws_internet_gateway" "infra" {
  vpc_id = module.vpc.vpc_id
  tags   = { Name = "project-a-igw" }
}

resource "aws_route" "default_via_igw" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = element(module.vpc.private_route_table_ids, count.index)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.infra.id
}
