# Flavor key -> flavor_name (public VK Cloud catalog names, subset).

variable "flavors" {
  description = "Flavor key to flavor_name"
  type        = map(string)
  default = {
    std_2_4   = "STD3-2-4"
    std_4_8   = "STD3-4-8"
    std_8_16  = "STD3-8-16"
    gpu_v100  = "GPU1-16-48-V100-1"
  }
}
