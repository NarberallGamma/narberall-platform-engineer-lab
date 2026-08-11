variable "region" {
  description = "(Optional, String, ForceNew) Specifies the region in which to create the VIP. If omitted, the provider-level region will be used. Changing this will create a new VIP resource."
  type        = string
  default     = null
}

variable "vip_name" {
  description = "(Optional, String) Specifies a unique name for the VIP."
  type        = string
  default     = null
}

variable "network_id" {
  description = "(Required, String, ForceNew) Specifies the network ID of the VPC subnet to which the VIP belongs. Changing this will create a new VIP resource."
  type        = string
}

variable "ip_version" {
  description = "(Optional, Int, ForceNew) Specifies the IP version, either 4 (default) or 6. Changing this will create a new VIP resource."
  type        = number
  default     = null
}

variable "ip_address" {
  description = "(Optional, String, ForceNew) Specifies the IP address desired in the subnet for this VIP. Changing this will create a new VIP resource."
  type        = string
  default     = null
}

variable "port_ids" {
  description = "(Required, List) An array of one or more IDs of the ports to attach the vip to."
  type        = list(string)
}
