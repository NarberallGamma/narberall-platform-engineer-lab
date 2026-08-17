variable "access_key" {
  description = "Cloud.ru Advanced (SberCloud) access key for the Terraform service account"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Cloud.ru Advanced (SberCloud) secret key for the Terraform service account"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Cloud.ru Advanced region"
  type        = string
  default     = "ru-moscow-1"
}

variable "project_name" {
  description = "IAM project name tag"
  type        = string
  default     = "project-a"
}

variable "rds_db_password" {
  description = "Placeholder for RDS db.password (required by provider). Not applied: ignore_changes on db."
  type        = string
  sensitive   = true
  default     = ""
}
