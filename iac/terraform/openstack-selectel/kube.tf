resource "openstack_compute_instance_v2" "bastion" {
  name            = "project-a-bastion"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_name     = "m1.small"
  key_pair        = "tfadm-example"
  security_groups = ["default"]

  network {
    uuid = openstack_networking_network_v2.default.id
  }

  lifecycle {
    ignore_changes = [image_id]
  }
}

resource "openstack_compute_instance_v2" "kube_master" {
  count           = 3
  name            = format("project-a-master-%02d", count.index + 1)
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

resource "openstack_compute_instance_v2" "kube_worker" {
  count           = 3
  name            = format("project-a-worker-%02d", count.index + 1)
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_name     = "m1.xlarge"
  key_pair        = "tfadm-example"
  security_groups = ["default"]

  network {
    uuid = openstack_networking_network_v2.default.id
  }

  lifecycle {
    ignore_changes = [image_id]
  }
}

resource "openstack_compute_instance_v2" "gitlab" {
  name            = "project-a-gitlab"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_name     = "m1.xlarge"
  key_pair        = "tfadm-example"
  security_groups = ["default"]

  network {
    uuid = openstack_networking_network_v2.default.id
  }
}

resource "openstack_compute_instance_v2" "postgres" {
  count           = 2
  name            = format("project-a-pg-%02d", count.index + 1)
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_name     = "m1.large"
  key_pair        = "tfadm-example"
  security_groups = ["default"]

  network {
    uuid = openstack_networking_network_v2.default.id
  }
}
