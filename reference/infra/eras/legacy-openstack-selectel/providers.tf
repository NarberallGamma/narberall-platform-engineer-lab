variable "os_auth_url" { type = string }
variable "os_region" { type = string }
variable "sel_account" { type = string }
variable "project_name" { type = string }
variable "server_image_name" {
  type    = string
  default = "Ubuntu 22.04 LTS 64-bit"
}

provider "selectel" {
  auth_url    = var.os_auth_url
  auth_region = var.os_region
  domain_name = var.sel_account
}

provider "openstack" {
  tenant_name         = var.project_name
  project_domain_name = var.sel_account
  user_domain_name    = var.sel_account
  auth_url            = var.os_auth_url
  region              = var.os_region
}
