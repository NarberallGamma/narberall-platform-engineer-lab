# Illustrative compose (not wired to a live backend in this lab).
# In real delivery, point module sources at ../../modules/* and configure provider/backend.

module "vpc" {
  source = "../../modules/vpc"

  vpc_name = "project-a-dev-vpc"
  vpc_cidr = "10.10.0.0/16"
  tags = {
    env = "dev"
  }
}

module "subnet" {
  source = "../../modules/subnet"

  vpc_id = module.vpc.vpc_id
  subnets = {
    app = {
      name              = "project-a-dev-app"
      cidr              = "10.10.1.0/24"
      gateway_ip        = "10.10.1.1"
      availability_zone = "ru-example-1a"
    }
  }
}
