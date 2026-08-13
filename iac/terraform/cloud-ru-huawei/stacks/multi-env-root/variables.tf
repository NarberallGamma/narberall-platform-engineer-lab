variable "region" {
  type    = string
  default = "ru-example-1"
}

variable "access_key" {
  type      = string
  sensitive = true
}

variable "secret_key" {
  type      = string
  sensitive = true
}

variable "image_ubuntu_id" {
  type        = string
  description = "Ubuntu image ID (example value in tfvars.example)"
}

variable "prod_key_pair" {
  type = string
}

variable "prod_security_group_id" {
  type = string
}

variable "prod_subnet_id" {
  type = string
}

variable "prod_vpc_id" {
  type = string
}

variable "prod_db_subnet_id" {
  type = string
}

variable "prod_db_vpc_id" {
  type = string
}

variable "prod_db_password" {
  type      = string
  sensitive = true
}

variable "preprod_subnet_id" {
  type = string
}

variable "preprod_vpc_id" {
  type = string
}

variable "preprod_key_pair" {
  type = string
}

variable "preprod_security_group_id" {
  type = string
}
