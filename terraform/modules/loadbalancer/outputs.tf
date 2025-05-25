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
  value       = var.domain_name != ""
}

output "domain_name" {
  description = "Domain name used for the load balancer"
  value       = var.domain_name
}

output "dns_zone_nameservers" {
  description = "Nameservers for the DNS zone"
  value       = var.domain_name != "" ? google_dns_managed_zone.default[0].name_servers : []
}

output "ssl_certificate_name" {
  description = "Name of the managed SSL certificate"
  value       = var.domain_name != "" ? google_compute_managed_ssl_certificate.default[0].name : null
}

output "ssl_certificate_domains" {
  description = "Domains covered by the SSL certificate"
  value       = var.domain_name != "" ? google_compute_managed_ssl_certificate.default[0].managed[0].domains : []
}

output "deployment_urls" {
  description = "URLs to access your deployment"
  value = {
    global_ip     = google_compute_global_address.lb_ip.address
    http_url      = "http://${google_compute_global_address.lb_ip.address}"
    https_url     = var.domain_name != "" ? "https://${var.domain_name}" : "HTTPS not configured"
    www_url       = var.domain_name != "" ? "https://www.${var.domain_name}" : "WWW not configured"
    health_check  = var.domain_name != "" ? "https://${var.domain_name}/health" : "http://${google_compute_global_address.lb_ip.address}/health"
  }
}

output "nameserver_configuration" {
  description = "Nameserver configuration instructions"
  value = var.domain_name != "" ? {
    message = "Configure these nameservers at your domain registrar:"
    nameservers = google_dns_managed_zone.default[0].name_servers
    domain = var.domain_name
  } : null
}