variable "az" {
  description = "Availability zone short key to Cloud.ru name"
  type        = map(string)
  default = {
    a = "ru-moscow-1a"
    b = "ru-moscow-1b"
    c = "ru-moscow-1c"
    e = "ru-moscow-1e"
  }
}
