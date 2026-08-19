# Selectel Cloud: volume-boot (Cinder) + AZ split. Image-boot guests stay in kube.tf.

locals {
  kube_az = ["ru-3a", "ru-3b", "ru-3a"]
}

resource "openstack_blockstorage_volume_v3" "kube_master_root" {
  count             = 3
  name              = format("project-a-master-root-%02d", count.index + 1)
  availability_zone = local.kube_az[count.index]
  region            = var.os_region
  size              = 50
  volume_type       = format("fast.%s", local.kube_az[count.index])
  image_id          = data.openstack_images_image_v2.ubuntu.id

  lifecycle {
    ignore_changes = [image_id]
  }
}

resource "openstack_blockstorage_volume_v3" "kube_master_etcd" {
  count             = 3
  name              = format("project-a-master-etcd-%02d", count.index + 1)
  description       = "etcd and kubernetes certs"
  availability_zone = local.kube_az[count.index]
  region            = var.os_region
  size              = 10
  volume_type       = format("fast.%s", local.kube_az[count.index])
}

resource "openstack_compute_instance_v2" "kube_master_bootvol" {
  count             = 3
  name              = format("project-a-master-bv-%02d", count.index + 1)
  flavor_name       = "custom-c4m10d0"
  key_pair          = "tfadm-example"
  availability_zone = local.kube_az[count.index]
  security_groups   = ["default"]

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.kube_master_root[count.index].id
    source_type           = "volume"
    destination_type      = "volume"
    delete_on_termination = true
    boot_index            = 0
  }

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.kube_master_etcd[count.index].id
    source_type           = "volume"
    destination_type      = "volume"
    delete_on_termination = true
    boot_index            = 1
  }

  network {
    uuid        = openstack_networking_network_v2.kube.id
    fixed_ip_v4 = format("10.10.1.%d", 10 + count.index)
  }

  lifecycle {
    ignore_changes = [image_id, block_device]
  }
}

resource "openstack_blockstorage_volume_v3" "kube_bastion_root" {
  name              = "project-a-bastion-root"
  availability_zone = "ru-3b"
  region            = var.os_region
  size              = 30
  volume_type       = "fast.ru-3b"
  image_id          = data.openstack_images_image_v2.ubuntu.id

  lifecycle {
    ignore_changes = [image_id]
  }
}

resource "openstack_compute_instance_v2" "kube_bastion_bootvol" {
  name              = "project-a-bastion-bv"
  flavor_name       = "custom-c1m2d0"
  key_pair          = "tfadm-example"
  availability_zone = "ru-3b"
  security_groups   = ["default"]

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.kube_bastion_root.id
    source_type           = "volume"
    destination_type      = "volume"
    delete_on_termination = true
    boot_index            = 0
  }

  network {
    uuid        = openstack_networking_network_v2.kube.id
    fixed_ip_v4 = "10.10.1.5"
  }

  lifecycle {
    ignore_changes = [image_id, block_device]
  }
}
