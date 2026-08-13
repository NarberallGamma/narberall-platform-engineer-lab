# Provider auth only. Catalog maps: ./variables/ (module.catalog / local.*).

variable "auth_url" {
  description = "Identity authentication URL (Keystone)"
  type        = string
}

variable "username" {
  description = "Service user name (domain from user_domain_name)"
  type        = string
}

variable "password" {
  description = "Service user password"
  type        = string
  sensitive   = true
}

variable "project_id" {
  description = "OpenStack project id"
  type        = string
}

variable "region" {
  description = "Provider region"
  type        = string
}

variable "project_name" {
  description = "Console project name (tags / docs only)"
  type        = string
}

variable "user_domain_name" {
  description = "User domain for the service account"
  type        = string
}
