# Admin Webapp Module Outputs

output "global_ip_address" {
  description = "Global IP address of the admin webapp load balancer"
  value       = google_compute_global_address.admin_webapp_ip.address
}

output "admin_webapp_url" {
  description = "HTTPS URL of the admin webapp"
  value       = "https://${var.admin_domain}"
}


output "backend_service_name" {
  description = "Name of the backend service"
  value       = google_compute_backend_service.admin_webapp.name
}

output "load_balancer_ip_name" {
  description = "Name of the reserved global IP"
  value       = google_compute_global_address.admin_webapp_ip.name
}

output "health_check_name" {
  description = "Name of the health check"
  value       = google_compute_health_check.admin_webapp.name
}

output "iap_status" {
  description = "IAP configuration status"
  value = {
    enabled    = true
    client_id  = var.oauth_client_id
    users      = length(var.authorized_users)
  }
}

output "dns_configuration" {
  description = "DNS configuration details"
  value = var.dns_zone_name != "" ? {
    zone     = var.dns_zone_name
    domain   = var.admin_domain
    ip       = google_compute_global_address.admin_webapp_ip.address
    record   = "${var.admin_domain}."
  } : null
}

output "firewall_rule_name" {
  description = "Name of the health check firewall rule"
  value       = google_compute_firewall.admin_webapp_health_check.name
}

output "summary" {
  description = "Complete admin webapp deployment summary"
  value = {
    url              = "https://${var.admin_domain}"
    ip_address       = google_compute_global_address.admin_webapp_ip.address
    iap_enabled      = true
    authorized_users = var.authorized_users
    health_check     = var.health_check_path
    backend_timeout  = var.backend_timeout
  }
}