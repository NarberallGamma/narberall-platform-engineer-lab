variable "images" {
  description = "IMS image UUID catalog (fake IDs in this lab)"
  type        = map(string)
  default = {
    ubuntu_24_04 = "00000000-0000-4000-8000-000000000701"
    debian_12    = "00000000-0000-4000-8000-000000000702"
  }
}
