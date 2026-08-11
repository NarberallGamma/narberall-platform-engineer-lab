# Current-style multi-env root: ECS / compute for prod (sanitized names).

resource "sbercloud_compute_instance" "prod_gitlab" {
  name                  = "project-a-prod-gitlab"
  flavor_id             = "c7n.2xlarge.2"
  image_id              = var.image_ubuntu_id
  key_pair              = var.prod_key_pair
  security_group_ids    = [var.prod_security_group_id]
  availability_zone     = "ru-example-1a"
  description           = "GitLab for prod stand"
  system_disk_type      = "ESSD"
  system_disk_size      = 90

  data_disks {
    type = "ESSD"
    size = 300
  }

  network {
    uuid = var.prod_db_subnet_id
  }

  lifecycle {
    ignore_changes = [
      user_data,
      data_disks,
      image_id,
    ]
  }

  tags = {
    env     = "prod"
    project = "project-a"
    role    = "gitlab"
  }
}

resource "sbercloud_compute_instance" "prod_vault" {
  for_each = {
    "1" = "ru-example-1a"
    "2" = "ru-example-1b"
    "3" = "ru-example-1c"
  }

  name               = "project-a-prod-vault-${each.key}"
  flavor_id          = "c7n.large.2"
  image_id           = var.image_ubuntu_id
  key_pair           = var.prod_key_pair
  security_group_ids = [var.prod_security_group_id]
  availability_zone  = each.value
  description        = "Vault raft node ${each.key}"
  system_disk_type   = "ESSD"
  system_disk_size   = 30

  data_disks {
    type = "ESSD"
    size = 50
  }

  network {
    uuid = var.prod_db_subnet_id
  }

  lifecycle {
    ignore_changes = [user_data, data_disks, image_id]
  }

  tags = {
    env     = "prod"
    project = "project-a"
    role    = "vault"
  }
}
