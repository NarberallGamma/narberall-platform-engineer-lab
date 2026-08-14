output "create_vm" {
  value = var.create_vm
}

output "catalog_keys" {
  value = {
    networks = keys(local.networks)
    storage  = local.storage.policy
    edge     = local.edge_name
  }
}

output "guest_init" {
  description = "No passwords. Length check only."
  value = {
    initscript_chars = length(local.guest_initscript)
    extra_users      = var.guest_extra_users
  }
}
