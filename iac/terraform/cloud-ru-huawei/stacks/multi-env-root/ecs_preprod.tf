resource "sbercloud_compute_instance" "preprod_gitlab" {
  name               = "project-a-preprod-gitlab"
  flavor_id          = "c7n.xlarge.2"
  image_id           = var.image_ubuntu_id
  key_pair           = var.preprod_key_pair
  security_group_ids = [var.preprod_security_group_id]
  availability_zone  = "ru-example-1a"
  description        = "GitLab for preprod stand"
  system_disk_type   = "SSD"
  system_disk_size   = 80

  data_disks {
    type = "SSD"
    size = 200
  }

  network {
    uuid = var.preprod_subnet_id
  }

  lifecycle {
    ignore_changes = [user_data, data_disks, image_id]
  }

  tags = {
    env     = "preprod"
    project = "project-a"
    role    = "gitlab"
  }
}
