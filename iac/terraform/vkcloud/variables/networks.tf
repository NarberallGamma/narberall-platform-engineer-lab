# All project networks: short key -> UUID (fake IDs in this lab).

variable "networks" {
  description = "Network key to Neutron network UUID"
  type        = map(string)
  default = {
    office = "00000000-0000-4000-8000-000000000001"
    app    = "00000000-0000-4000-8000-000000000002"
    db     = "00000000-0000-4000-8000-000000000003"
    ext    = "00000000-0000-4000-8000-000000000004"
  }
}
