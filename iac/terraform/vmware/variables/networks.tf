variable "networks" {
  type        = map(string)
  description = "Org network display names (catalog key -> VCD name)"
  default = {
    org_routed = "net-app-50"
  }
}

variable "network_cidrs" {
  type = map(string)
  default = {
    org_routed = "10.10.50.0/24"
  }
}

variable "network_gw" {
  type        = map(string)
  description = "Gateway IP (do not assign to a VM)"
  default = {
    org_routed = "10.10.50.1"
  }
}

variable "edge_name" {
  type    = string
  default = "example-edge-01"
}
