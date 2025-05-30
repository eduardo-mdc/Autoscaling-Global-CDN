output "zone_id" {
  description = "The ID of the created DNS zone"
  value       = google_dns_managed_zone.dns_zone.id
}

output "zone_name" {
  description = "The name of the created DNS zone"
  value       = google_dns_managed_zone.dns_zone.name
}

output "zone_dns_name" {
  description = "The DNS name of the created zone"
  value       = google_dns_managed_zone.dns_zone.dns_name
}

output "name_servers" {
  description = "The list of nameservers that should be configured with the domain registrar"
  value       = google_dns_managed_zone.dns_zone.name_servers
}

output "main_domain_record" {
  description = "The A record for the main domain"
  value       = google_dns_record_set.main_domain.name
}

output "grafana_subdomain_record" {
  description = "The A record for the grafana subdomain"
  value       = google_dns_record_set.grafana_subdomain.name
}

output "www_subdomain_record" {
  description = "The A record for the www subdomain"
  value       = google_dns_record_set.www_subdomain.name
}

output "is_private_zone" {
  description = "Whether this is a private DNS zone"
  value       = var.is_private_zone
}

output "dnssec_enabled" {
  description = "Whether DNSSEC is enabled for this zone"
  value       = var.enable_dnssec
}
