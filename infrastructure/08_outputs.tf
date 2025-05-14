// Admin VM outputs
output "admin_vm_public_ip" {
  value       = azurerm_public_ip.admin_public_ip.ip_address
  description = "Public IP address of the admin VM"
}

output "admin_vm_private_ip" {
  value       = azurerm_network_interface.admin_nic.private_ip_address
  description = "Private IP address of the admin VM"
}

// Load Balancer endpoints
output "europe_endpoint" {
  value       = azurerm_public_ip.europe_lb_ip.fqdn
  description = "FQDN of the Europe load balancer"
}

output "america_endpoint" {
  value       = azurerm_public_ip.america_lb_ip.fqdn
  description = "FQDN of the America load balancer"
}

output "asia_endpoint" {
  value       = azurerm_public_ip.asia_lb_ip.fqdn
  description = "FQDN of the Asia load balancer"
}

// Traffic Manager endpoint
output "traffic_manager_endpoint" {
  value       = azurerm_traffic_manager_profile.global_traffic_manager.fqdn
  description = "FQDN of the Traffic Manager"
}

output "vmss_instance_count" {
  description = "Number of VMSS instances in each region"
  value = {
    europe = azurerm_linux_virtual_machine_scale_set.europe_vmss.instances
    america = azurerm_linux_virtual_machine_scale_set.america_vmss.instances
    asia = azurerm_linux_virtual_machine_scale_set.asia_vmss.instances
  }
}
