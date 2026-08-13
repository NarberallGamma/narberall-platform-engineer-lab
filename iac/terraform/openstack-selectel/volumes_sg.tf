resource "openstack_blockstorage_volume_v3" "postgres_data" {
  count = 2
  name  = format("project-a-pg-data-%02d", count.index + 1)
  size  = 200
}

resource "openstack_compute_volume_attach_v2" "postgres_data" {
  count       = 2
  instance_id = openstack_compute_instance_v2.postgres[count.index].id
  volume_id   = openstack_blockstorage_volume_v3.postgres_data[count.index].id
}

resource "openstack_compute_servergroup_v2" "kube_masters" {
  name     = "project-a-kube-masters"
  policies = ["anti-affinity"]
}

resource "openstack_networking_secgroup_v2" "app" {
  name        = "project-a-app"
  description = "application tier"
}

resource "openstack_networking_secgroup_rule_v2" "app_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.app.id
}

resource "openstack_networking_floatingip_v2" "bastion" {
  pool = "external"
}
