resource "openstack_networking_network_v2" "default" {
  name           = "project-legacy-b-default"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "default" {
  network_id = openstack_networking_network_v2.default.id
  name       = "project-legacy-b-default"
  cidr       = "10.198.0.0/24"
  dns_nameservers = [
    "8.8.8.8",
    "1.1.1.1",
  ]
}

data "openstack_images_image_v2" "ubuntu" {
  name        = var.server_image_name
  most_recent = true
}
