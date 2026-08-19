resource "openstack_compute_servergroup_v2" "postgres" {
  name     = "project-a-postgres"
  policies = ["anti-affinity"]
}

resource "openstack_blockstorage_volume_v3" "postgres_root" {
  count             = 2
  name              = format("project-a-pg-root-%02d", count.index + 1)
  availability_zone = element(["ru-3a", "ru-3b"], count.index)
  region            = var.os_region
  size              = 50
  volume_type       = format("universal.%s", element(["ru-3a", "ru-3b"], count.index))
  image_id          = data.openstack_images_image_v2.ubuntu.id

  lifecycle {
    ignore_changes = [image_id]
  }
}

resource "openstack_blockstorage_volume_v3" "postgres_data_ha" {
  count             = 2
  name              = format("project-a-pg-data-ha-%02d", count.index + 1)
  availability_zone = element(["ru-3a", "ru-3b"], count.index)
  region            = var.os_region
  size              = 850
  volume_type       = format("universal.%s", element(["ru-3a", "ru-3b"], count.index))
}

resource "openstack_blockstorage_volume_v3" "postgres_wal" {
  count             = 2
  name              = format("project-a-pg-wal-%02d", count.index + 1)
  availability_zone = element(["ru-3a", "ru-3b"], count.index)
  region            = var.os_region
  size              = 30
  volume_type       = format("universal.%s", element(["ru-3a", "ru-3b"], count.index))
}

resource "openstack_compute_instance_v2" "postgres_ha" {
  count             = 2
  name              = format("project-a-pg-ha-%02d", count.index + 1)
  flavor_name       = "custom-c8m32d0"
  key_pair          = "tfadm-example"
  availability_zone = element(["ru-3a", "ru-3b"], count.index)
  security_groups   = ["default"]

  scheduler_hints {
    group = openstack_compute_servergroup_v2.postgres.id
  }

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.postgres_root[count.index].id
    source_type           = "volume"
    destination_type      = "volume"
    delete_on_termination = true
    boot_index            = 0
  }

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.postgres_data_ha[count.index].id
    source_type           = "volume"
    destination_type      = "volume"
    delete_on_termination = true
    boot_index            = 1
  }

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.postgres_wal[count.index].id
    source_type           = "volume"
    destination_type      = "volume"
    delete_on_termination = true
    boot_index            = 2
  }

  network {
    uuid        = openstack_networking_network_v2.default.id
    fixed_ip_v4 = format("10.198.0.%d", 20 + count.index)
  }

  lifecycle {
    ignore_changes = [image_id, block_device, scheduler_hints]
  }
}
