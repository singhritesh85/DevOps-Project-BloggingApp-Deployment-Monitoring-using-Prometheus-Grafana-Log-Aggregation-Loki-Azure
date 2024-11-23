output "acr_login_server" {
  description = "The URL of the Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server         #azurerm_container_registry.acr.*.login_server
}

output "azure_loki_vm" {
  description = "Private IP Addresses for Azure VM"
  value       = azurerm_linux_virtual_machine.azure_vm_loki.*.private_ip_address 
}
