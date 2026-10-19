output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "ID de la red de la aplicación"
  value       = module.network.vnet_id
}

output "application_subnet_id" {
  description = "ID de la subnet de la capa de aplicación"
  value       = module.network.subnet_ids["application"]
}
