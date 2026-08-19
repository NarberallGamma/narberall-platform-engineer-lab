resource "openstack_blockstorage_volume_v3" "gitlab" {
  name              = "project-a-gitlab-root"
  availability_zone = "ru-3b"
  region            = var.os_region
  size              = 100
  volume_type       = "universal.ru-3b"
  image_id          = data.openstack_images_image_v2.ubuntu.id

  lifecycle {
    ignore_changes = [image_id]
  }
}

resource "openstack_compute_instance_v2" "gitlab_dualnic" {
  name              = "project-a-gitlab-edge"
  flavor_name       = "custom-c4m12d0"
  key_pair          = "tfadm-example"
  availability_zone = "ru-3b"
  security_groups   = ["default"]

  block_device {
    uuid             = openstack_blockstorage_volume_v3.gitlab.id
    source_type      = "volume"
    destination_type = "volume"
    boot_index       = 0
  }

  network {
    uuid        = data.openstack_networking_network_v2.external.id
    fixed_ip_v4 = var.gitlab_external_ip
  }

  network {
    uuid        = openstack_networking_network_v2.default.id
    fixed_ip_v4 = "10.198.0.4"
  }

  lifecycle {
    ignore_changes = [image_id, block_device]
  }
}
