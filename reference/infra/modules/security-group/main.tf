resource "sbercloud_networking_secgroup" "this" {
    region = var.region 
    name        = var.name
    description = var.description
    enterprise_project_id = var.enterprise_project_id 
    delete_default_rules = var.delete_default_rules 
}
