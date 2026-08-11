# Cross-env peering + security groups (modules used from a root).

module "prod_sg_app" {
  source = "../../modules/security-group"

  name         = "project-a-prod-app"
  description  = "app tier"
  project_name = "project-a-prod"
}

module "prod_sg_app_rules" {
  source = "../../modules/security-group-rule"

  security_group_id = module.prod_sg_app.id
  project_name      = "project-a-prod"
  rules = [
    {
      name             = "https-internal"
      region           = "ru-example-1"
      direction        = "ingress"
      ethertype        = "IPv4"
      description      = "HTTPS from private nets"
      protocol         = "tcp"
      port_range_min   = "443"
      port_range_max   = "443"
      remote_ip_prefix = "10.0.0.0/8"
      action           = "allow"
      priority         = 1
    }
  ]
}

module "prod_dev_peering" {
  source = "../../modules/peering"

  name         = "project-a-prod-dev"
  local_vpc_id = sbercloud_vpc.prod.id
  peer_vpc_id  = sbercloud_vpc.dev.id
}

module "prod_nat_eip" {
  source = "../../modules/eip"

  bandwidth_name = "project-a-prod-nat"
  bandwidth_size = 100
}
