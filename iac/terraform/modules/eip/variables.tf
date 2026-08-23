variable "create_eip" {
  description = "Whether to create an EIP. When false, the resource is not created."
  type        = bool
  default     = true
}

variable "create_associate" {
  description = "Whether to create an EIP-to-instance association. Requires instance_id."
  type        = bool
  default     = false
}

variable "region" {
  description = "Region where the EIP will be created. When unset, the provider region is used."
  type        = string
  default     = null
}

variable "publicip_type" {
  description = "EIP type. Allowed value: \"5_bgp\"."
  type        = string
  default     = "5_bgp"
}

variable "publicip_ip_address" {
  description = "Desired IP address. Must fall within an available range."
  type        = string
  default     = null
}

variable "publicip_port_id" {
  description = "Port ID to bind the EIP to (for example a VIP port). When set, the EIP is associated with this port immediately."
  type        = string
  default     = null
}

variable "bandwidth_share_type" {
  description = "Bandwidth share type: PER (dedicated) or WHOLE (shared)."
  type        = string
  default     = "PER"
}

variable "bandwidth_name" {
  description = "Bandwidth name."
  type        = string
  default     = null
}

variable "bandwidth_size" {
  description = "Bandwidth size in Mbit/s."
  type        = number
  default     = 5
}

variable "bandwidth_charge_mode" {
  description = "Bandwidth charging mode: traffic or bandwidth."
  type        = string
  default     = "traffic"
}

variable "bandwidth_id" {
  description = "ID of an existing shared bandwidth. When set, share_type is ignored."
  type        = string
  default     = null
}

variable "charging_mode" {
  description = "EIP charging mode: prePaid or postPaid."
  type        = string
  default     = "postPaid"
}

variable "period" {
  description = "Billing period (for prePaid)."
  type        = number
  default     = null
}

variable "period_unit" {
  description = "Period unit: month or year."
  type        = string
  default     = null
}

variable "auto_renew" {
  description = "Auto-renewal (for prePaid)."
  type        = string
  default     = null
}

variable "enterprise_project_id" {
  description = "Enterprise project ID."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags for the EIP."
  type        = map(string)
  default     = {}
}

# Variables for association via sbercloud_compute_eip_associate (alternative method)
variable "instance_id" {
  description = "ECS instance ID to bind the EIP to (used only when create_associate = true)."
  type        = string
  default     = null
}

variable "fixed_ip" {
  description = "Fixed IP address on the instance network interface (used only when create_associate = true)."
  type        = string
  default     = null
}
