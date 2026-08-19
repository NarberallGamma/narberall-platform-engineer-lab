# Purpose ECS next to the generic prod/preprod/platform files.
# Same flavor / disk / lifecycle pattern as ecs_platform.tf.

resource "sbercloud_compute_instance" "prod_gitlab" {
  name               = "project-a-prod-gitlab"
  flavor_id          = "c7n.2xlarge.2"
  image_id           = var.image_ubuntu_id
  key_pair           = var.prod_key_pair
  security_group_ids = [var.prod_security_group_id]
  availability_zone  = "ru-example-1a"
  system_disk_type   = "ESSD"
  system_disk_size   = 100

  network {
    uuid = sbercloud_vpc_subnet.prod_app.id
  }

  lifecycle {
    ignore_changes = [user_data, image_id]
  }

  tags = {
    role    = "gitlab"
    env     = "prod"
    project = "project-a"
  }
}

resource "sbercloud_compute_instance" "prod_vault" {
  name               = "project-a-prod-vault"
  flavor_id          = "c7n.xlarge.2"
  image_id           = var.image_ubuntu_id
  key_pair           = var.prod_key_pair
  security_group_ids = [var.prod_security_group_id]
  availability_zone  = "ru-example-1b"
  system_disk_type   = "ESSD"
  system_disk_size   = 80

  network {
    uuid = sbercloud_vpc_subnet.prod_app.id
  }

  lifecycle {
    ignore_changes = [user_data, image_id]
  }

  tags = {
    role    = "vault"
    env     = "prod"
    project = "project-a"
  }
}

resource "sbercloud_compute_instance" "prod_runner" {
  name               = "project-a-prod-runner"
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
    role    = "ci-runner"
    env     = "prod"
    project = "project-a"
  }
}

resource "sbercloud_compute_instance" "prod_redis" {
  name               = "project-a-prod-redis"
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
    role    = "redis"
    env     = "prod"
    project = "project-a"
  }
}

resource "sbercloud_compute_instance" "prod_monitor" {
  name               = "project-a-prod-monitor"
  flavor_id          = "c7n.xlarge.2"
  image_id           = var.image_ubuntu_id
  key_pair           = var.prod_key_pair
  security_group_ids = [var.prod_security_group_id]
  availability_zone  = "ru-example-1a"
  system_disk_type   = "ESSD"
  system_disk_size   = 200

  network {
    uuid = sbercloud_vpc_subnet.prod_app.id
  }

  lifecycle {
    ignore_changes = [user_data, image_id]
  }

  tags = {
    role    = "monitor"
    env     = "prod"
    project = "project-a"
  }
}
