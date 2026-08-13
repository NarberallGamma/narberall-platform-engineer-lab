# Key pair names present on imported instances (generic).

variable "key_pairs" {
  description = "Key pair key to Nova key_name"
  type        = map(string)
  default = {
    linux_ops = "ops-linux"
    gpu_lab   = "gpu-lab"
  }
}
