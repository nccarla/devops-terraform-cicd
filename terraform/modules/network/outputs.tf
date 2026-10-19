output "vnet_id" {
  description = "ID de la Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "subnet_ids" {
  description = "Mapa de IDs de las subnets, indexado por su clave lógica"

  value = {
    for key, subnet in azurerm_subnet.main :
    key => subnet.id
  }
}
