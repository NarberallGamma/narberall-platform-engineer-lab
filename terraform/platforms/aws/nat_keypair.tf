resource "aws_key_pair" "ops" {
  key_name   = "project-a-ops"
  public_key = var.ssh_public_key
}

variable "ssh_public_key" {
  type = string
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "project-a-nat" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = module.vpc.public_subnets[0]
  tags          = { Name = "project-a-nat" }
}
