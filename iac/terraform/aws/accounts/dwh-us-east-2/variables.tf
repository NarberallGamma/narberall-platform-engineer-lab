variable "target_region" {
  type    = string
  default = "us-east-2"
}

variable "cidr" {
  type    = string
  default = "10.50.0.0/20"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-2a", "us-east-2b"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.50.0.0/24", "10.50.1.0/24"]
}

variable "key_name" {
  type    = string
  default = "tfadm-example"
}

variable "office_cidrs" {
  type    = list(string)
  default = ["203.0.113.10/32"]
}

variable "peer_staging_cidr" {
  type    = string
  default = "10.10.0.0/20"
}
