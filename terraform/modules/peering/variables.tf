variable "local_vpc_id" {
  description = "ID of the local VPC (requester)"
  type        = string
}

variable "peer_vpc_id" {
  description = "ID of the peer VPC (accepter, HUB)"
  type        = string
}

variable "peer_tenant_id" {
  description = "Tenant ID of the peer VPC (if different)"
  type        = string
  default     = null
}

variable "region" {
  description = "(Optional, String, ForceNew) The region in which to create the VPC peering connection. If omitted, the provider-level region will be used. Changing this creates a new VPC peering connection resource."
  default     = null
}

variable "name" {
  description = "(Required, String) - Specifies the name of the VPC peering connection. The value can contain 1 to 64 characters."
  type        = string
}

