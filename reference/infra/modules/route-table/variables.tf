variable "region" {
    description = "(Optional, String, ForceNew) The region in which to create the vpc route table. If omitted, the provider-level region will be used. Changing this creates a new resource."
    type        = string
    default     = null
}

variable "vpc_id" {
  description = "(Required, String, ForceNew) - Specifies the VPC ID for which a route table is to be added. Changing this creates a new resource."
  type        = string
}

variable "name" {
  description = "(Required, String) - Specifies the route table name. The value is a string of no more than 64 characters that can contain letters, digits, underscores (_), hyphens (-), and periods (.)."
  type        = string
}

variable "description" {
  description = "(Optional, String) - Specifies the supplementary information about the route table. The value is a string of no more than 255 characters and cannot contain angle brackets (< or >)."
  type = string
  default = null
}

variable "subnets" {
  description = "(Optional, List) - Specifies an array of one or more subnets associating with the route table.\n -> NOTE: The custom route table associated with a subnet affects only the outbound traffic. The default route table determines the inbound traffic."
  type        = list(string)
  default     = null
}

variable "routes" {
  description = "List of custom routes to add to the table"
  type = list(object({
    destination = string
    type  = string
    nexthop = string
    description = optional(string)
  }))
}

