# Example: one file per environment slice (sanitized names).

resource "sbercloud_vpc" "dev" {
  name = "project-a-dev-vpc"
  cidr = "10.10.0.0/16"
  tags = {
    env     = "dev"
    project = "project-a"
    managed = "terraform"
  }
}

resource "sbercloud_vpc_subnet" "dev_app" {
  vpc_id     = sbercloud_vpc.dev.id
  name       = "project-a-dev-app"
  cidr       = "10.10.1.0/24"
  gateway_ip = "10.10.1.1"
}
