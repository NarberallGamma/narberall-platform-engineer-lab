# Subnet IDs from sibling Terragrunt live/*/vpc_subnet. Not managed in this repository.
# NGFW has four subnets; IDs are listed without name mapping (order in state is not name-stable).

variable "subnets" {
  description = "Subnet short name to UUID (managed by Terragrunt live)"
  type        = map(string)
  default = {
    prod    = "00000000-0000-4000-8000-000000000201"
    preprod = "00000000-0000-4000-8000-000000000202"
    dev     = "00000000-0000-4000-8000-000000000203"
    public  = "00000000-0000-4000-8000-000000000204"
    appsec  = "00000000-0000-4000-8000-000000000205"
  }
}

variable "subnet_cidrs" {
  description = "Primary subnet CIDR by short name (documentation ranges)"
  type        = map(string)
  default = {
    prod    = "10.10.0.0/24"
    preprod = "10.10.16.0/24"
    dev     = "10.10.4.0/24"
    public  = "10.10.12.0/24"
    appsec  = "10.10.8.0/24"
  }
}

variable "ngfw_subnet_ids" {
  description = "Four NGFW subnet UUIDs (untrust/trust/mgmt/ha). Do not import."
  type        = list(string)
  default = [
    "00000000-0000-4000-8000-000000000211",
    "00000000-0000-4000-8000-000000000212",
    "00000000-0000-4000-8000-000000000213",
    "00000000-0000-4000-8000-000000000214",
  ]
}

variable "ngfw_subnet_cidrs" {
  description = "NGFW subnet CIDRs from Terragrunt live/ngfw"
  type        = map(string)
  default = {
    untrust = "10.10.128.0/24"
    trust   = "10.10.129.0/24"
    mgmt    = "10.10.130.0/24"
    ha      = "10.10.131.0/24"
  }
}
