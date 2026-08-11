# modules/sbercloud_ecs/main.tf

locals {
  instance_configs_raw = var.instances != null ? {
    for key, inst in var.instances : key => {
      availability_zone  = inst.availability_zone
      networks           = inst.networks
      security_group_ids = coalesce(inst.security_group_ids, var.security_group_ids)
      flavor_id          = coalesce(inst.flavor_id, var.flavor_id)
      image_id           = inst.image_id != null ? inst.image_id : var.image_id
      image_name         = inst.image_name != null ? inst.image_name : var.image_name
      system_disk_type   = coalesce(inst.system_disk_type, var.system_disk_type)
      system_disk_size   = coalesce(inst.system_disk_size, var.system_disk_size)
      data_disks         = coalesce(inst.data_disks, var.data_disks)
      instance_tags      = coalesce(inst.tags, {})
    }
  } : {
    for i in range(var.instance_count) : format("%02d", i + 1) => {
      availability_zone  = null
      networks           = var.networks
      security_group_ids = var.security_group_ids
      flavor_id          = var.flavor_id
      image_id           = var.image_id
      image_name         = var.image_name
      system_disk_type   = var.system_disk_type
      system_disk_size   = var.system_disk_size
      data_disks         = var.data_disks
      instance_tags      = {}
    }
  }

  keys = keys(local.instance_configs_raw)

  # Зоны доступности
  zones_raw = length(var.availability_zones) == 0 ? null : (
    length(var.availability_zones) == 1 ? [for _ in local.keys : var.availability_zones[0]] : (
      length(var.availability_zones) >= length(local.keys) ?
      slice(var.availability_zones, 0, length(local.keys)) :
      var.availability_zones
    )
  )

  instance_configs = {
    for idx, key in local.keys : key => merge(local.instance_configs_raw[key], {
      zone = coalesce(
        local.instance_configs_raw[key].availability_zone,
        try(local.zones_raw[idx], null)
      )
    })
  }

  anti_affinity_group_id = (
    var.anti_affinity_enabled &&
    (var.scheduler_hints == null || try(var.scheduler_hints.group, "") == "")
  ) ? sbercloud_compute_servergroup.this[0].id : try(var.scheduler_hints.group, null)
}

resource "sbercloud_compute_servergroup" "this" {
  count    = var.anti_affinity_enabled && (var.scheduler_hints == null || try(var.scheduler_hints.group, "") == "") ? 1 : 0
  name     = "${var.instance_name}-anti-affinity"
  policies = ["anti-affinity"]
}

resource "sbercloud_compute_instance" "this" {
  for_each = local.instance_configs

  name               = "${var.instance_name}-${each.key}"
  flavor_id          = each.value.flavor_id
  availability_zone  = each.value.zone

  # Образ: если задан image_name (не null и не ""), используем его, иначе image_id
  image_id   = (each.value.image_name != null && each.value.image_name != "") ? null : each.value.image_id
  image_name = (each.value.image_name != null && each.value.image_name != "") ? each.value.image_name : null

  system_disk_type = each.value.system_disk_type
  system_disk_size = each.value.system_disk_size

  dynamic "data_disks" {
    for_each = each.value.data_disks
    content {
      type        = data_disks.value.type
      size        = data_disks.value.size
      snapshot_id = try(data_disks.value.snapshot_id, null)
      kms_key_id  = try(data_disks.value.kms_key_id, null)
    }
  }

  dynamic "network" {
    for_each = each.value.networks
    content {
      uuid              = network.value.uuid
      fixed_ip_v4       = network.value.fixed_ip != "" ? network.value.fixed_ip : null
      ipv6_enable       = network.value.ipv6_enable
      source_dest_check = network.value.source_dest_check
      access_network    = network.value.access_network
    }
  }

  security_group_ids = each.value.security_group_ids

  dynamic "scheduler_hints" {
    for_each = local.anti_affinity_group_id != null ? [1] : []
    content {
      group   = local.anti_affinity_group_id
      tenancy = try(var.scheduler_hints.tenancy, null)
      deh_id  = try(var.scheduler_hints.deh_id, null)
    }
  }

  dynamic "bandwidth" {
    for_each = var.bandwidth != null ? [var.bandwidth] : []
    content {
      share_type  = bandwidth.value.share_type
      size        = bandwidth.value.size
      id          = try(bandwidth.value.id, null)
      charge_mode = try(bandwidth.value.charge_mode, null)
    }
  }
  eip_type = var.eip_type
  eip_id   = var.eip_id

  key_pair    = var.key_pair
  admin_pass  = var.admin_pass
  private_key = var.private_key
  user_data   = var.user_data
  tags        = merge(var.tags, each.value.instance_tags)
  description = var.description
  stop_before_destroy         = var.stop_before_destroy
  delete_disks_on_termination = var.delete_disks_on_termination
  delete_eip_on_termination   = var.delete_eip_on_termination
  enterprise_project_id       = var.enterprise_project_id
  user_id                     = var.user_id
  agency_name                 = var.agency_name
  agent_list                  = var.agent_list
  power_action                = var.power_action

  charging_mode = var.charging_mode
  period_unit   = var.period_unit
  period        = var.period
  auto_renew    = var.auto_renew
  region        = var.region
}
