// outputs.tf - Output values after deployment (simplified)

// Admin VM outputs
output "admin_vm_public_ip" {
  value       = azurerm_public_ip.admin_public_ip.ip_address
  description = "Public IP address of the admin VM"
}

output "admin_vm_private_ip" {
  value       = azurerm_network_interface.admin_nic.private_ip_address
  description = "Private IP address of the admin VM"
}

// Container Apps outputs
output "europe_container_app_url" {
  value       = "https://${azurerm_container_app.europe_app.ingress[0].fqdn}"
  description = "URL of the Europe Container App"
}

output "america_container_app_url" {
  value       = "https://${azurerm_container_app.america_app.ingress[0].fqdn}"
  description = "URL of the America Container App"
}

output "asia_container_app_url" {
  value       = "https://${azurerm_container_app.asia_app.ingress[0].fqdn}"
  description = "URL of the Asia Container App"
}

// Traffic manager output
output "traffic_manager_url" {
  value       = "https://${azurerm_traffic_manager_profile.global_traffic_manager.fqdn}"
  description = "Global Traffic Manager URL"
}

// Container Apps Environment outputs
output "europe_container_app_environment_id" {
  value       = azurerm_container_app_environment.europe.id
  description = "ID of the Europe Container App Environment"
}

output "america_container_app_environment_id" {
  value       = azurerm_container_app_environment.america.id
  description = "ID of the America Container App Environment"
}

output "asia_container_app_environment_id" {
  value       = azurerm_container_app_environment.asia.id
  description = "ID of the Asia Container App Environment"
}

// Resource Group output
output "resource_group_id" {
  value       = azurerm_resource_group.cdn_rg.id
  description = "ID of the main resource group"
}