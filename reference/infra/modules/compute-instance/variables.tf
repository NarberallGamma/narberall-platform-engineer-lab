variable "instances" {
  description = "Карта индивидуальных конфигураций инстансов. Ключ — суффикс имени (напр. \"01\")."
  type = map(object({
    availability_zone  = optional(string)
    networks = list(object({
      uuid              = string
      fixed_ip          = optional(string, "")
      ipv6_enable       = optional(bool, false)
      source_dest_check = optional(bool, true)
      access_network    = optional(bool, false)
    }))
    security_group_ids = optional(list(string))
    flavor_id          = optional(string)
    image_id           = optional(string)
    image_name         = optional(string)
    system_disk_type   = optional(string)
    system_disk_size   = optional(number)
    data_disks = optional(list(object({
      type        = string
      size        = number
      snapshot_id = optional(string)
      kms_key_id  = optional(string)
    })))
    tags = optional(map(string))
  }))
  default = null
}

# --- Общие параметры (используются, если instances не задана, или как fallback) ---
variable "instance_count" {
  description = "Количество инстансов (если instances не задана)"
  type        = number
  default     = 1
}

variable "instance_name" {
  description = "Базовое имя инстанса"
  type        = string
}

variable "availability_zones" {
  description = "Список зон доступности (общий fallback). 1 элемент — для всех; длина = instance_count — каждому своя."
  type        = list(string)
  default     = []
}

variable "networks" {
  description = "Общий список сетей (без fixed_ip, если используется без instances)."
  type = list(object({
    uuid              = string
    fixed_ip          = optional(string, "")
    ipv6_enable       = optional(bool, false)
    source_dest_check = optional(bool, true)
    access_network    = optional(bool, false)
  }))
  default = []
}

variable "flavor_id" {
  description = "ID флейвора (общий)"
  type        = string
}

variable "image_id" {
  description = "ID образа (общий, если не указан image_name)"
  type        = string
  default     = null
}

variable "image_name" {
  description = "Имя образа (общий, приоритетнее image_id)"
  type        = string
  default     = ""
}

variable "security_group_ids" {
  description = "Общий список групп безопасности (если не переопределён в instances)"
  type        = list(string)
  default     = []
}

variable "system_disk_type" {
  type    = string
  default = "GPSSD"
}
variable "system_disk_size" {
  type    = number
  default = 40
}
variable "data_disks" {
  type = list(object({
    type        = string
    size        = number
    snapshot_id = optional(string)
    kms_key_id  = optional(string)
  }))
  default = []
}

variable "anti_affinity_enabled" {
  type    = bool
  default = false
}
variable "scheduler_hints" {
  type = object({
    group   = optional(string)
    tenancy = optional(string)
    deh_id  = optional(string)
  })
  default = null
}

variable "eip_type" { 
  type = string
  default = null 
}

variable "bandwidth" {
  type = object({
    share_type  = string
    size        = number
    id          = optional(string)
    charge_mode = optional(string)
  })
  default = null
}
variable "eip_id" {
  description = "ID существующего EIP"
  type        = string
  default     = null
}

variable "key_pair" {
  description = "Имя SSH-ключевой пары"
  type        = string
  default     = null
}

variable "admin_pass" {
  description = "Пароль администратора (несовместим с cloud-init)"
  type        = string
  default     = null
  sensitive   = true
}

variable "private_key" {
  description = "Приватный ключ для замены/отвязки key_pair"
  type        = string
  default     = null
  sensitive   = true
}

variable "user_data" {
  description = "Cloud-init данные"
  type        = string
  default     = null
}

variable "tags" {
  description = "Теги инстанса"
  type        = map(string)
  default     = {}
}

variable "description" {
  description = "Описание инстанса"
  type        = string
  default     = ""
}

variable "stop_before_destroy" {
  description = "Останавливать ли инстанс перед удалением"
  type        = bool
  default     = true
}

variable "delete_disks_on_termination" {
  description = "Удалять ли диски при удалении инстанса"
  type        = bool
  default     = false
}

variable "delete_eip_on_termination" {
  description = "Удалять ли EIP при удалении инстанса"
  type        = bool
  default     = true
}

variable "enterprise_project_id" {
  description = "ID проекта предприятия"
  type        = string
  default     = null
}

variable "user_id" {
  description = "ID пользователя (обязательно при key_pair в pre-paid)"
  type        = string
  default     = null
}

variable "agency_name" {
  description = "Имя IAM агентства"
  type        = string
  default     = null
}

variable "agent_list" {
  description = "Список агентов через запятую"
  type        = string
  default     = null
}

variable "power_action" {
  description = "Действие с питанием: ON, OFF, REBOOT, FORCE-OFF, FORCE-REBOOT"
  type        = string
  default     = null
}

variable "charging_mode" {
  description = "Режим оплаты: postPaid или prePaid"
  type        = string
  default     = "postPaid"
}

variable "period_unit" {
  description = "Единица периода при prePaid"
  type        = string
  default     = null
}

variable "period" {
  description = "Период при prePaid"
  type        = number
  default     = null
}

variable "auto_renew" {
  description = "Автопродление при prePaid"
  type        = string
  default     = null
}

variable "region" {
  description = "Регион (если не указан на уровне провайдера)"
  type        = string
  default     = null
}
