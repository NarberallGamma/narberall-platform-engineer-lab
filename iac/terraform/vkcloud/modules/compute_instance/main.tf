# Greenfield VK Cloud VM: image by properties (names include a build date),
# SSH via cloud-init so the instance does not depend on who owns the Nova keypair.

terraform {
  required_providers {
    vkcs = {
      source  = "vk-cs/vkcs"
      version = "~> 0.17"
    }
  }
}

data "vkcs_images_image" "this" {
  visibility  = "public"
  most_recent = true
  properties = {
    mcs_os_distro  = var.os_distro
    mcs_os_version = var.os_version
  }
}

data "vkcs_compute_flavor" "this" {
  name = var.flavor_name
}

locals {
  user_data = length(var.ssh_public_keys) == 0 ? null : join("\n", concat(
    ["#cloud-config", "ssh_authorized_keys:"],
    [for k in var.ssh_public_keys : "  - ${k}"],
  ))
}

resource "vkcs_compute_instance" "this" {
  name              = var.name
  flavor_id         = data.vkcs_compute_flavor.this.id
  key_pair          = var.key_pair
  user_data         = local.user_data
  availability_zone = var.availability_zone
  security_groups   = var.security_groups

  block_device {
    uuid                  = data.vkcs_images_image.this.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = var.boot_volume_size
    volume_type           = var.boot_volume_type
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid        = var.network_id
    fixed_ip_v4 = var.fixed_ip
  }

  lifecycle {
    ignore_changes = [block_device[0].uuid]
  }
}
