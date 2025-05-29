# terraform/modules/fleet/outputs.tf

output "config_membership_id" {
  description = "Membership ID of the config cluster"
  value       = google_gke_hub_membership.config_cluster.membership_id
}

output "member_membership_ids" {
  description = "Membership IDs of member clusters"
  value = {
    for region, membership in google_gke_hub_membership.member_clusters :
    region => membership.membership_id
  }
}

output "mci_global_ip" {
  description = "Global IP address reserved for MCI"
  value       = google_compute_global_address.mci_ip.address
}

output "mci_global_ip_name" {
  description = "Name of the global IP for MCI"
  value       = google_compute_global_address.mci_ip.name
}

output "dns_zone_nameservers" {
  description = "Nameservers for the DNS zone"
  value       = var.domain_name != "" ? google_dns_managed_zone.mci_zone[0].name_servers : []
}

output "deployment_urls" {
  description = "URLs to access your deployment"
  value = {
    global_ip     = google_compute_global_address.mci_ip.address
    http_url      = "http://${google_compute_global_address.mci_ip.address}"
    https_url     = var.domain_name != "" ? "https://${var.domain_name}" : "HTTPS not configured"
    www_url       = var.domain_name != "" ? "https://www.${var.domain_name}" : "WWW not configured"
    health_check  = var.domain_name != "" ? "https://${var.domain_name}/health" : "http://${google_compute_global_address.mci_ip.address}/health"
  }
}