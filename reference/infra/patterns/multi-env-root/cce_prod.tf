# Kubernetes (CCE-class) prod cluster shape.

resource "sbercloud_cce_cluster" "prod" {
  name                   = "project-a-prod"
  flavor_id              = "cce.s2.small"
  vpc_id                 = var.prod_vpc_id
  subnet_id              = var.prod_subnet_id
  cluster_type           = "VirtualMachine"
  cluster_version        = "v1.33"
  container_network_type = "overlay_l2"
  container_network_cidr = "172.16.0.0/16"
  service_network_cidr   = "10.247.0.0/16"
  description            = "project-a prod kubernetes"
  authentication_mode    = "rbac"

  masters {
    availability_zone = "ru-example-1a"
  }
  masters {
    availability_zone = "ru-example-1b"
  }
  masters {
    availability_zone = "ru-example-1c"
  }
}

resource "sbercloud_cce_node_pool" "prod" {
  cluster_id         = sbercloud_cce_cluster.prod.id
  name               = "project-a-prod-workers"
  os                 = "HCE OS 2.0"
  flavor_id          = "c7n.2xlarge.4"
  initial_node_count = 6
  availability_zone  = "ru-example-1a"
  key_pair           = var.prod_key_pair
  scall_enable       = true
  min_node_count     = 4
  max_node_count     = 10
  priority           = 0
  runtime            = "containerd"

  labels = {
    "node-role.kubernetes.io/worker" = "true"
  }

  hostname_config {
    type = "cceNodeName"
  }

  extend_params {
    max_pods = 256
  }

  extension_scale_groups {
    metadata {
      name = "az-a"
    }
    spec {
      flavor = "c7n.2xlarge.4"
      az     = "ru-example-1a"
      autoscaling {
        enable             = true
        extension_priority = 1
        min_node_count     = 2
        max_node_count     = 4
      }
    }
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}
