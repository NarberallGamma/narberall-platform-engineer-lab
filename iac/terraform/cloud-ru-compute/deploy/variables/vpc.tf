# VPC IDs from sibling Terragrunt live/*/vpc. Not managed in this repository.

variable "vpcs" {
  description = "VPC short name to UUID (managed by Terragrunt live)"
  type        = map(string)
  default = {
    prod    = "00000000-0000-4000-8000-000000000101"
    preprod = "00000000-0000-4000-8000-000000000102"
    dev     = "00000000-0000-4000-8000-000000000103"
    public  = "00000000-0000-4000-8000-000000000104"
    appsec  = "00000000-0000-4000-8000-000000000105"
    ngfw    = "00000000-0000-4000-8000-000000000106"
  }
}

variable "vpc_cidrs" {
  description = "VPC CIDR by short name (documentation ranges)"
  type        = map(string)
  default = {
    prod    = "10.10.0.0/22"
    preprod = "10.10.16.0/22"
    dev     = "10.10.4.0/22"
    public  = "10.10.12.0/22"
    appsec  = "10.10.8.0/22"
    ngfw    = "10.10.128.0/22"
  }
}
