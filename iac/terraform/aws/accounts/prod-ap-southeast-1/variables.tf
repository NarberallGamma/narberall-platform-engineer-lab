variable "target_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.40.0.0/24", "10.40.1.0/24", "10.40.2.0/24"]
}

variable "key_name" {
  type    = string
  default = "tfadm-example"
}

variable "windows_username" {
  type    = string
  default = "winadmin"
}

variable "windows_password" {
  type      = string
  default   = "ChangeMeAtApply"
  sensitive = true
}

variable "office_cidrs" {
  type    = list(string)
  default = ["203.0.113.10/32", "198.51.100.20/32"]
}

variable "vpn_cidrs" {
  type    = list(string)
  default = ["203.0.113.50/32"]
}

variable "kube_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "peer_staging_cidr" {
  type    = string
  default = "10.10.0.0/20"
}
