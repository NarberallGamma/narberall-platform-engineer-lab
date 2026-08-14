# Guest init: random passwords (30) + SSH pubkeys.
# Script goes to VCD customization.initscript (hosted VCD often caps at 1500 chars).
# Passwords: artifacts/<vm>/guest_secrets.json (not in git).

locals {
  guest_ssh_pub_file = var.admin_ssh_public_key_file != "" ? var.admin_ssh_public_key_file : "${path.module}/files/ssh/authorized_keys"
  guest_ssh_pub = trimspace(join("\n", [
    for line in split("\n", replace(file(local.guest_ssh_pub_file), "\r", "")) : trimspace(line)
    if trimspace(line) != "" && !startswith(trimspace(line), "#")
  ]))

  guest_pw_override = trimspace(var.guest_password_override)
  guest_pw_root     = local.guest_pw_override != "" ? local.guest_pw_override : random_password.guest_root.result
  guest_pw_ubuntu   = local.guest_pw_override != "" ? local.guest_pw_override : random_password.guest_ubuntu.result

  guest_extra_specs = [
    for u in var.guest_extra_users : {
      name     = u
      password = local.guest_pw_override != "" ? local.guest_pw_override : random_password.guest_extra[u].result
    }
  ]

  guest_initscript = templatefile("${path.module}/templates/guest_init.sh.tftpl", {
    ssh_pub     = local.guest_ssh_pub
    pw_root     = local.guest_pw_root
    pw_ubuntu   = local.guest_pw_ubuntu
    extra_users = local.guest_extra_specs
    nic_ip      = local.vm_db_pg_01_nic.ip_address
    nic_prefix  = split("/", local.network_cidrs.org_routed)[1]
    nic_gw      = local.network_gw.org_routed
  })
}

resource "random_password" "guest_root" {
  length           = var.guest_password_length
  special          = true
  override_special = "@#%*+-="
  min_lower        = 3
  min_upper        = 3
  min_numeric      = 3
  min_special      = 3
}

resource "random_password" "guest_ubuntu" {
  length           = var.guest_password_length
  special          = true
  override_special = "@#%*+-="
  min_lower        = 3
  min_upper        = 3
  min_numeric      = 3
  min_special      = 3
}

resource "random_password" "guest_extra" {
  for_each         = toset(var.guest_extra_users)
  length           = var.guest_password_length
  special          = true
  override_special = "@#%*+-="
  min_lower        = 3
  min_upper        = 3
  min_numeric      = 3
  min_special      = 3
}

resource "local_file" "guest_secrets" {
  filename        = "${path.module}/artifacts/db-pg-01/guest_secrets.json"
  content = jsonencode({
    vm              = "db-pg-01"
    password_length = local.guest_pw_override != "" ? length(local.guest_pw_override) : var.guest_password_length
    users           = ["root", "ubuntu"]
    extra_users     = var.guest_extra_users
  })
  file_permission = "0600"
}

check "guest_initscript_len" {
  assert {
    condition     = length(local.guest_initscript) <= 1500
    error_message = "VCD guest initscript exceeds 1500 chars. Fewer guest_extra_users or a shorter pubkey."
  }
}

check "guest_ssh_pub_safe" {
  assert {
    condition     = length(local.guest_ssh_pub) > 20 && !strcontains(local.guest_ssh_pub, "'")
    error_message = "SSH pubkey missing or contains a single quote (breaks initscript)."
  }
}

check "guest_extra_user_names" {
  assert {
    condition = alltrue([
      for u in var.guest_extra_users : can(regex("^[a-z_][a-z0-9_-]*$", u))
    ])
    error_message = "guest_extra_users: Linux login [a-z_][a-z0-9_-]*"
  }
}

check "guest_extra_not_builtin" {
  assert {
    condition     = length(setintersection(toset(var.guest_extra_users), toset(["root", "ubuntu"]))) == 0
    error_message = "root and ubuntu are builtin; do not list them in guest_extra_users"
  }
}
