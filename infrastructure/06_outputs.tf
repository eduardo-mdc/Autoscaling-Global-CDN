// 06_outputs.tf - Output values

// Admin VM outputs
output "admin_vm_public_ip" {
  value       = azurerm_public_ip.admin_public_ip.ip_address
  description = "Public IP address of the admin VM"
}

output "admin_vm_private_ip" {
  value       = azurerm_network_interface.admin_nic.private_ip_address
  description = "Private IP address of the admin VM"
}

// Container App endpoints
output "europe_endpoint" {
  value       = azurerm_container_app.europe_cdn_app.ingress[0].fqdn
  description = "FQDN of the Europe CDN container app"
}

output "america_endpoint" {
  value       = azurerm_container_app.america_cdn_app.ingress[0].fqdn
  description = "FQDN of the America CDN container app"
}

output "asia_endpoint" {
  value       = azurerm_container_app.asia_cdn_app.ingress[0].fqdn
  description = "FQDN of the Asia CDN container app"
}

// Traffic Manager endpoint
output "traffic_manager_endpoint" {
  value       = azurerm_traffic_manager_profile.global_traffic_manager.fqdn
  description = "FQDN of the Traffic Manager"
}

// Storage account details
output "storage_account_name" {
  value       = azurerm_storage_account.cdn_storage.name
  description = "Name of the storage account"
}

output "file_share_name" {
  value       = azurerm_storage_share.cdn_share.name
  description = "Name of the file share for content distribution"
}