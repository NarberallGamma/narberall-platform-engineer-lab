resource "openstack_compute_instance_v2" "runner" {
  name            = "project-a-runner"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_name     = "m1.large"
  key_pair        = "tfadm-example"
  security_groups = ["default"]

  network {
    uuid = openstack_networking_network_v2.default.id
  }

  lifecycle {
    ignore_changes = [image_id]
  }
}

resource "openstack_compute_instance_v2" "vault" {
  name            = "project-a-vault"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_name     = "m1.large"
  key_pair        = "tfadm-example"
  security_groups = ["default"]

  network {
    uuid = openstack_networking_network_v2.default.id
  }

  lifecycle {
    ignore_changes = [image_id]
  }
}

resource "openstack_compute_instance_v2" "redis" {
  name            = "project-a-redis"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_name     = "m1.medium"
  key_pair        = "tfadm-example"
  security_groups = ["default"]

  network {
    uuid = openstack_networking_network_v2.default.id
  }

  lifecycle {
    ignore_changes = [image_id]
  }
}

resource "openstack_compute_instance_v2" "monitor" {
  name            = "project-a-monitor"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_name     = "m1.large"
  key_pair        = "tfadm-example"
  security_groups = ["default"]

  network {
    uuid = openstack_networking_network_v2.default.id
  }

  lifecycle {
    ignore_changes = [image_id]
  }
}

resource "openstack_compute_instance_v2" "proxy" {
  name            = "project-a-proxy"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_name     = "m1.medium"
  key_pair        = "tfadm-example"
  security_groups = ["default"]

  network {
    uuid = openstack_networking_network_v2.default.id
  }

  lifecycle {
    ignore_changes = [image_id]
  }
}
