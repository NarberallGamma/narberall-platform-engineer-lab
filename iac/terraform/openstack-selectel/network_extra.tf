resource "openstack_networking_network_v2" "kube" {
  name           = "project-a-kube"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "kube" {
  network_id = openstack_networking_network_v2.kube.id
  name       = "project-a-kube"
  cidr       = "10.10.1.0/24"
  dns_nameservers = [
    "8.8.8.8",
    "1.1.1.1",
  ]
}

data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}
