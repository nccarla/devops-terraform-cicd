variable "name" {
  description = "Nombre de la Virtual Network"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group donde se crea la red"
  type        = string
}

variable "location" {
  description = "Región de Azure"
  type        = string
}

variable "address_space" {
  description = "Espacios CIDR asignados a la Virtual Network"
  type        = list(string)
}

variable "subnets" {
  description = "Subnets administradas por el módulo"

  type = map(object({
    name             = string
    address_prefixes = list(string)
  }))
}

variable "tags" {
  description = "Tags aplicados a los recursos que los admiten"
  type        = map(string)
  default     = {}
}
