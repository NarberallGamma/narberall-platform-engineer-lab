# Purpose: dns-dev.tf (private DNS on the dev VPC for CCE kubelet / VPC DNS)
#
# Image pull on CCE workers uses VPC DNS (100.125.0.0/16 class), not CoreDNS
# and not pod hostAliases. A records here are the node-level source of truth.
# proxy_pattern RECURSIVE: names missing from this zone still resolve via public DNS.

locals {
  dns_private_dev_a_records = {
    "registry-dev.example.com." = {
      records     = [sbercloud_compute_instance.gitlab_dev.network[0].fixed_ip_v4]
      description = "GitLab/registry DEV, CCE image pull"
    }
    "git-dev.example.com." = {
      records     = [sbercloud_compute_instance.gitlab_dev.network[0].fixed_ip_v4]
      description = "GitLab DEV"
    }
    "vault-dev.example.com." = {
      records     = [sbercloud_compute_instance.vault_dev.network[0].fixed_ip_v4]
      description = "Vault DEV"
    }
  }
}

resource "sbercloud_dns_zone" "example_com_private_dev" {
  name          = "example.com."
  zone_type     = "private"
  email         = "platform@example.com"
  description   = "Dev VPC: internal A for registry/git/vault; RECURSIVE for other example.com names"
  ttl           = 300
  proxy_pattern = "RECURSIVE"

  router {
    router_id     = local.vpcs.dev
    router_region = var.region
  }

  tags = {
    project = var.project_name
    env     = "dev"
    managed = "terraform"
  }
}

resource "sbercloud_dns_recordset" "example_com_private_dev_a" {
  for_each = local.dns_private_dev_a_records

  zone_id     = sbercloud_dns_zone.example_com_private_dev.id
  name        = each.key
  type        = "A"
  ttl         = 300
  description = each.value.description
  records     = each.value.records

  tags = {
    project = var.project_name
    env     = "dev"
    managed = "terraform"
  }
}
