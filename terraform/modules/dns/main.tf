# Google Cloud DNS Module
# Creates a managed zone and necessary DNS records

# Create the managed DNS zone
resource "google_dns_managed_zone" "dns_zone" {
  name        = "${var.project_name}-dns-zone"
  dns_name    = var.dns_name != "" ? var.dns_name : "${var.domain_name}."
  description = var.description
  labels      = var.labels
  
  # Configure visibility (public or private)
  dynamic "private_visibility_config" {
    for_each = var.is_private_zone ? [1] : []
    content {
      dynamic "networks" {
        for_each = var.private_visibility_config
        content {
          network_url = networks.value.network_url
        }
      }
    }
  }
  
  # Configure DNSSEC if enabled
  dynamic "dnssec_config" {
    for_each = var.enable_dnssec ? [1] : []
    content {
      kind          = "dns#managedZoneDnsSecConfig"
      non_existence = "nsec3"
      state         = "on"
      
      default_key_specs {
        algorithm  = "rsasha256"
        key_length = 2048
        key_type   = "keySigning"
        kind       = "dns#dnsKeySpec"
      }
      
      default_key_specs {
        algorithm  = "rsasha256"
        key_length = 1024
        key_type   = "zoneSigning"
        kind       = "dns#dnsKeySpec"
      }
    }
  }
}

# Create A record for the main domain pointing to the load balancer
resource "google_dns_record_set" "main_domain" {
  name         = google_dns_managed_zone.dns_zone.dns_name
  managed_zone = google_dns_managed_zone.dns_zone.name
  type         = "A"
  ttl          = var.ttl
  
  rrdatas = [var.load_balancer_ip]
}

# Create A record for the grafana subdomain pointing to the Grafana VM
resource "google_dns_record_set" "grafana_subdomain" {
  name         = "grafana.${google_dns_managed_zone.dns_zone.dns_name}"
  managed_zone = google_dns_managed_zone.dns_zone.name
  type         = "A"
  ttl          = var.ttl
  
  rrdatas = [var.grafana_vm_ip]
}

# Create additional useful records (e.g., www subdomain)
resource "google_dns_record_set" "www_subdomain" {
  name         = "www.${google_dns_managed_zone.dns_zone.dns_name}"
  managed_zone = google_dns_managed_zone.dns_zone.name
  type         = "A"
  ttl          = var.ttl
  
  rrdatas = [var.load_balancer_ip]
}
