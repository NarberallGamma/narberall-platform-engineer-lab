variable "region" {
  type        = string
  description = "(Optional, String, ForceNew) Specifies the region in which to create the VPC. If omitted, the provider-level region will be used. Changing this creates a new VPC resource."
  default = null
}

variable "vpc_name" {
  type        = string
  description = "(Required, String) Specifies the name of the VPC. The name must be unique for a tenant. The value is a string of no more than 64 characters and can contain digits, letters, underscores (_), and hyphens (-)."
}

variable "vpc_cidr" {
  type        = string
  description = "(Required, String) Specifies the range of available subnets in the VPC. The value ranges from 10.0.0.0/8 to 10.255.255.0/24, 172.16.0.0/12 to 172.31.255.0/24, or 192.168.0.0/16 to 192.168.255.0/24."
}

variable "description" {
  type = string
  description = "(Optional, String) Specifies supplementary information about the VPC. The value is a string of no more than 255 characters and cannot contain angle brackets (< or >)."
  default = null
}

variable "tags" {
  description = "(Optional, Map) Specifies the key/value pairs to associate with the VPC."
  type        = map(string)
  default     = {}
}

variable "enterprise_project_id" {
  description = "(Optional, String, ForceNew) Specifies the enterprise project id of the VPC. Changing this creates a new VPC resource."
  type        = string
  default     = null
}

