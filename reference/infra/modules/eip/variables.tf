variable "create_eip" {
  description = "Создавать ли EIP. Если false, ресурс не создаётся."
  type        = bool
  default     = true
}

variable "create_associate" {
  description = "Создавать ли ассоциацию EIP с инстансом. Требует указания instance_id."
  type        = bool
  default     = false
}

variable "region" {
  description = "Регион, в котором будет создан EIP. Если не указан, используется регион провайдера."
  type        = string
  default     = null
}

variable "publicip_type" {
  description = "Тип EIP. Допустимое значение: \"5_bgp\"."
  type        = string
  default     = "5_bgp"
}

variable "publicip_ip_address" {
  description = "Желаемый IP-адрес. Должен находиться в доступном диапазоне."
  type        = string
  default     = null
}

variable "publicip_port_id" {
  description = "ID порта, к которому привязывается EIP (например, порт VIP). Если указан, EIP будет сразу ассоциирован с этим портом."
  type        = string
  default     = null
}

variable "bandwidth_share_type" {
  description = "Тип распределения пропускной способности: PER (выделенная) или WHOLE (общая)."
  type        = string
  default     = "PER"
}

variable "bandwidth_name" {
  description = "Имя полосы пропускания."
  type        = string
  default     = null
}

variable "bandwidth_size" {
  description = "Размер полосы пропускания в Мбит/с."
  type        = number
  default     = 5
}

variable "bandwidth_charge_mode" {
  description = "Режим оплаты полосы пропускания: traffic или bandwidth."
  type        = string
  default     = "traffic"
}

variable "bandwidth_id" {
  description = "ID существующей общей полосы пропускания. Если указан, share_type игнорируется."
  type        = string
  default     = null
}

variable "charging_mode" {
  description = "Режим оплаты EIP: prePaid или postPaid."
  type        = string
  default     = "postPaid"
}

variable "period" {
  description = "Период оплаты (для prePaid)."
  type        = number
  default     = null
}

variable "period_unit" {
  description = "Единица измерения периода: month или year."
  type        = string
  default     = null
}

variable "auto_renew" {
  description = "Автопродление (для prePaid)."
  type        = string
  default     = null
}

variable "enterprise_project_id" {
  description = "ID корпоративного проекта."
  type        = string
  default     = null
}

variable "tags" {
  description = "Теги для EIP."
  type        = map(string)
  default     = {}
}

# Переменные для ассоциации через sbercloud_compute_eip_associate (альтернативный способ)
variable "instance_id" {
  description = "ID инстанса ECS, к которому привязывается EIP (используется только если create_associate = true)."
  type        = string
  default     = null
}

variable "fixed_ip" {
  description = "Фиксированный IP-адрес на сетевом интерфейсе инстанса (используется только если create_associate = true)."
  type        = string
  default     = null
}
