#output "acr" {
#  description = "URL of the Azure Container Registry Created"
#  value       = "${module.aks}"
#}

output "acr_azure_loki_vm_private_ip" {
  description = "URL of the Azure Container Registry Created and Private IP Addresses for Azure VM"
  value       = "${module.aks}"
}
