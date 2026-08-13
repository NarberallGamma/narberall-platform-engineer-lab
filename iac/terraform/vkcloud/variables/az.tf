# Availability zones (public VK Cloud AZ names, subset).

variable "az" {
  description = "AZ key to availability_zone"
  type        = map(string)
  default = {
    core = "ME1"
    alt  = "MS1"
    gpu  = "PA2"
    edge = "GZ1"
  }
}
