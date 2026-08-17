# Purpose: cce.tf (CCE clusters). Node pool ECS are not imported as compute_instance.

# import: terraform import sbercloud_cce_cluster.dev_01 00000000-0000-4000-8000-000000000301
resource "sbercloud_cce_cluster" "dev_01" {
  name                   = "dev-01"
  flavor_id              = local.flavors.cce_s1_small
  vpc_id                 = local.vpcs.dev
  subnet_id              = local.subnets.dev
  cluster_type           = "VirtualMachine"
  cluster_version        = "v1.34"
  container_network_type = "overlay_l2"
  container_network_cidr = "10.80.0.0/16"
  service_network_cidr   = "10.81.0.0/16"
  authentication_mode    = "rbac"
  enterprise_project_id  = "0"
  masters {
    availability_zone = local.az.e
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      cluster_version,
      kube_config_raw,
      certificate_clusters,
      certificate_users,
      security_group_id,
      tags,
      hibernate,
      charging_mode,
    ]
  }
}

# import: terraform import sbercloud_cce_cluster.preprod_01 00000000-0000-4000-8000-000000000302
resource "sbercloud_cce_cluster" "preprod_01" {
  name                   = "preprod-01"
  flavor_id              = local.flavors.cce_s2_small
  vpc_id                 = local.vpcs.preprod
  subnet_id              = local.subnets.preprod
  cluster_type           = "VirtualMachine"
  cluster_version        = "v1.34"
  container_network_type = "overlay_l2"
  container_network_cidr = "10.82.0.0/16"
  service_network_cidr   = "10.83.0.0/16"
  authentication_mode    = "rbac"
  enterprise_project_id  = "0"
  masters {
    availability_zone = local.az.e
  }
  masters {
    availability_zone = local.az.c
  }
  masters {
    availability_zone = local.az.b
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      cluster_version,
      kube_config_raw,
      certificate_clusters,
      certificate_users,
      security_group_id,
      tags,
      hibernate,
      charging_mode,
    ]
  }
}

# import: terraform import sbercloud_cce_cluster.prod_01 00000000-0000-4000-8000-000000000303
resource "sbercloud_cce_cluster" "prod_01" {
  name                   = "prod-01"
  flavor_id              = local.flavors.cce_s2_small
  vpc_id                 = local.vpcs.prod
  subnet_id              = local.subnets.prod
  cluster_type           = "VirtualMachine"
  cluster_version        = "v1.34"
  container_network_type = "overlay_l2"
  container_network_cidr = "10.84.0.0/16"
  service_network_cidr   = "10.85.0.0/16"
  authentication_mode    = "rbac"
  enterprise_project_id  = "0"
  masters {
    availability_zone = local.az.e
  }
  masters {
    availability_zone = local.az.c
  }
  masters {
    availability_zone = local.az.b
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      cluster_version,
      kube_config_raw,
      certificate_clusters,
      certificate_users,
      security_group_id,
      tags,
      hibernate,
      charging_mode,
    ]
  }
}
