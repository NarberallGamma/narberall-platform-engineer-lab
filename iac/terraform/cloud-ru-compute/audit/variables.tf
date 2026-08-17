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
