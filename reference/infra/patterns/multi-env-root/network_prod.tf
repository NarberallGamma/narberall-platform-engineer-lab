resource "sbercloud_vpc" "prod" {
  name = "project-a-prod-vpc"
  cidr = "10.20.0.0/16"
  tags = {
    env     = "prod"
    project = "project-a"
    managed = "terraform"
  }
}

resource "sbercloud_vpc_subnet" "prod_app" {
  vpc_id     = sbercloud_vpc.prod.id
  name       = "project-a-prod-app"
  cidr       = "10.20.1.0/24"
  gateway_ip = "10.20.1.1"
}
