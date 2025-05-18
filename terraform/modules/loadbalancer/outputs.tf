output "load_balancer_ip" {
  description = "Global IP address of the load balancer"
  value       = google_compute_global_address.lb_ip.address
}

output "load_balancer_url" {
  description = "URL to access the load balancer"
  value       = "http://${google_compute_global_address.lb_ip.address}"
}

output "https_enabled" {
  description = "Whether HTTPS is enabled"
  value       = var.domain_name != "" && var.ssl_certificate != ""
}

output "domain_name" {
  description = "Domain name used for the load balancer"
  value       = var.domain_name
}

output "regional_domains" {
  description = "Map of regional domain names"
  value = var.domain_name != "" ? {
    for region in var.regions :
    region => "${region}.${var.domain_name}"
  } : {}
}