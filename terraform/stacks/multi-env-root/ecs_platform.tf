# Extra platform VMs often co-located with GitLab/Vault: LB/WAF edge, Teleport, app host.

resource "sbercloud_compute_instance" "prod_lb_waf" {
  name               = "project-a-prod-lb-waf"
  flavor_id          = "c7n.xlarge.2"
  image_id           = var.image_ubuntu_id
  key_pair           = var.prod_key_pair
  security_group_ids = [var.prod_security_group_id]
  availability_zone  = "ru-example-1a"
  system_disk_type   = "ESSD"
  system_disk_size   = 40

  network {
    uuid = sbercloud_vpc_subnet.prod_app.id
  }

  lifecycle {
    ignore_changes = [user_data, image_id]
  }

  tags = {
    role    = "lb-waf"
    env     = "prod"
    project = "project-a"
  }
}

resource "sbercloud_compute_instance" "prod_teleport" {
  name               = "project-a-prod-teleport"
  flavor_id          = "c7n.large.2"
  image_id           = var.image_ubuntu_id
  key_pair           = var.prod_key_pair
  security_group_ids = [var.prod_security_group_id]
  availability_zone  = "ru-example-1b"
  system_disk_type   = "ESSD"
  system_disk_size   = 40

  network {
    uuid = sbercloud_vpc_subnet.prod_app.id
  }

  lifecycle {
    ignore_changes = [user_data, image_id]
  }

  tags = {
    role    = "teleport"
    env     = "prod"
    project = "project-a"
  }
}

resource "sbercloud_compute_instance" "prod_app" {
  name               = "project-a-prod-app-01"
  flavor_id          = "c7n.xlarge.2"
  image_id           = var.image_ubuntu_id
  key_pair           = var.prod_key_pair
  security_group_ids = [var.prod_security_group_id]
  availability_zone  = "ru-example-1a"
  system_disk_type   = "ESSD"
  system_disk_size   = 80

  network {
    uuid = sbercloud_vpc_subnet.prod_app.id
  }

  lifecycle {
    ignore_changes = [user_data, image_id]
  }

  tags = {
    role    = "app"
    env     = "prod"
    project = "project-a"
  }
}
