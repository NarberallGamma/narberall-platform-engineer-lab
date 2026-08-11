variable "vpc_id" {
  description = "ID of the VPC where subnets will be created"
  type        = string
}

variable "subnets" {
  description = "Map of subnet configurations"
  type = map(object({
    name              = optional(string) # если не задано, будет сформировано из ключа
    cidr              = string
    gateway_ip        = string
    availability_zone = optional(string)
    tags              = optional(map(string))
    region            = optional(string)
    dhcp_lease_time   = optional(string)
    # можно добавить другие опциональные параметры
  }))
}
