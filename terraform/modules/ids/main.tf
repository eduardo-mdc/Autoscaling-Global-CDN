# Google Cloud IDS Module
# Creates Cloud IDS instances across multiple regions with packet mirroring

# Lista de regiões onde o Cloud IDS está disponível
locals {
  supported_regions = [
    "us-east1", "us-central1", "us-west1", 
    "europe-west1", "europe-west4",
    "asia-east1", "asia-northeast1"
  ]
  
  # Filtra apenas regiões suportadas
  filtered_regions = [
    for region in var.regions : region
    if contains(local.supported_regions, region)
  ]
}

# Create Cloud IDS Endpoint for each region
resource "google_cloud_ids_endpoint" "ids_endpoint" {
  # Use a lista filtrada de regiões em vez de var.regions
  for_each = toset(local.filtered_regions)

  name     = "${var.ids_instance_name_prefix}-${each.key}"
  location = each.key
  network  = var.network_self_links[each.key]
  severity = var.severity
  
  threat_exceptions = var.threat_exceptions
}

# Create packet mirroring for each region if enabled
resource "google_compute_packet_mirroring" "packet_mirroring" {
  # Também use filtered_regions aqui e combine com a condição enable_packet_mirroring
  for_each = var.enable_packet_mirroring ? toset(local.filtered_regions) : []

  name        = "packet-mirror-${each.key}"
  description = "Packet mirroring for Cloud IDS in ${each.key}"
  region      = each.key
  
  network {
    url = var.network_self_links[each.key]
  }
  
  collector_ilb {
    url = google_cloud_ids_endpoint.ids_endpoint[each.key].endpoint_forwarding_rule
  }
  
  mirrored_resources {
    subnetworks {
      url = var.subnet_self_links[each.key]
    }
  }
  
  depends_on = [google_cloud_ids_endpoint.ids_endpoint]
}
