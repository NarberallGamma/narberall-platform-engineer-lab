variable "region" {
  description  = "(Optional, String, ForceNew) The region in which to create the VPC route. If omitted, the provider-level region will be used. Changing this creates a new resource." 
  type         = string
  default      = null
}

variable vpc_id {
  description = "(Required, String, ForceNew) - Specifies the VPC for which a route is to be added. Changing this creates a new resource."
  type        = string
}

variable "destination" {
  description = "(Required, String, ForceNew) - Specifies the destination address in the CIDR notation format, for example, 192.168.200.0/24. The destination of each route must be unique and cannot overlap with any subnet in the VPC. Changing this creates a new resource."
  type        = string
}

variable "type" {
  description = "(Required, String) - Specifies the route type. Currently, the value can be: ecs, eni, vip, nat, peering, vpn, dc and cc."
  type        = string
  validation {
    condition     = contains(["ecs", "eni", "vip", "nat", "peering", "vpn", "dc", "cc"], var.type)
    error_message = "The value can be: ecs, eni, vip, nat, peering, vpn, dc and cc."
  }
}

variable "nexthop" {
  description = "(Required, String) - Specifies the next hop."
  type        = string
}

variable "description" {
  description = " (Optional, String) - Specifies the supplementary information about the route. The value is a string of no more than 255 characters and cannot contain angle brackets (< or >)."
  type = string
  default = null
}

variable "route_table_id" {
  description = "(Optional, String, ForceNew) - Specifies the route table ID for which a route is to be added. If the value is not set, the route will be added to the default route table."
  type        = string
  default     = null
}

