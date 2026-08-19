variable "target_region" {
  type    = string
  default = "eu-central-1"
}

variable "cidr" {
  type    = string
  default = "10.10.0.0/20"
}

variable "azs" {
  type    = list(string)
  default = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "private_subnets" {
  type = list(string)
  default = [
    "10.10.0.0/24", "10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24",
    "10.10.4.0/24", "10.10.5.0/24", "10.10.6.0/24", "10.10.7.0/24",
    "10.10.8.0/24", "10.10.9.0/24", "10.10.10.0/24", "10.10.11.0/24",
    "10.10.12.0/24", "10.10.13.0/24", "10.10.14.0/24", "10.10.15.0/24",
  ]
}

variable "key_name" {
  type    = string
  default = "tfadm-example"
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

variable "eks_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "peer_prod_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "acm_staging_arn" {
  type    = string
  default = ""
}

variable "waf_web_acl_arn" {
  type    = string
  default = ""
}
