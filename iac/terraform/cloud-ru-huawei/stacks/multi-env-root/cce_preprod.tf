resource "sbercloud_cce_cluster" "preprod" {
  name                   = "project-a-preprod"
  flavor_id              = "cce.s2.small"
  vpc_id                 = var.preprod_vpc_id
  subnet_id              = var.preprod_subnet_id
  cluster_type           = "VirtualMachine"
  cluster_version        = "v1.33"
  container_network_type = "overlay_l2"
  container_network_cidr = "172.20.0.0/16"
  service_network_cidr   = "10.248.0.0/16"
  description            = "project-a preprod kubernetes"
  authentication_mode    = "rbac"

  masters {
    availability_zone = "ru-example-1a"
  }
}

resource "sbercloud_cce_node_pool" "preprod" {
  cluster_id         = sbercloud_cce_cluster.preprod.id
  name               = "project-a-preprod-workers"
  os                 = "HCE OS 2.0"
  flavor_id          = "c7n.xlarge.4"
  initial_node_count = 3
  availability_zone  = "ru-example-1a"
  key_pair           = var.preprod_key_pair
  scall_enable       = true
  min_node_count     = 2
  max_node_count     = 6
  runtime            = "containerd"

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}
