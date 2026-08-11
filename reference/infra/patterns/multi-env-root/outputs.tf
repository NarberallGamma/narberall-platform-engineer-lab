output "prod_cce_id" {
  value = sbercloud_cce_cluster.prod.id
}

output "preprod_cce_id" {
  value = sbercloud_cce_cluster.preprod.id
}

output "prod_gitlab_id" {
  value = sbercloud_compute_instance.prod_gitlab.id
}

output "prod_vault_ids" {
  value = { for k, v in sbercloud_compute_instance.prod_vault : k => v.id }
}

output "prod_rds_id" {
  value = sbercloud_rds_instance.prod_postgresql.id
}
