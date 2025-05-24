output "ids_endpoints" {
  description = "Map of region to Cloud IDS endpoint details"
  value = {
    for region, endpoint in google_cloud_ids_endpoint.ids_endpoint : region => {
      id                    = endpoint.id
      name                  = endpoint.name
      self_link             = endpoint.self_link
      endpoint_id           = endpoint.endpoint_id
      severity              = endpoint.severity
      forwarding_rule       = endpoint.endpoint_forwarding_rule
      threat_exceptions     = endpoint.threat_exceptions
    }
  }
}

output "ids_endpoint_ids" {
  description = "Map of region to Cloud IDS endpoint IDs"
  value = {
    for region, endpoint in google_cloud_ids_endpoint.ids_endpoint : region => endpoint.id
  }
}

output "ids_endpoint_names" {
  description = "Map of region to Cloud IDS endpoint names"
  value = {
    for region, endpoint in google_cloud_ids_endpoint.ids_endpoint : region => endpoint.name
  }
}

output "packet_mirroring_ids" {
  description = "Map of region to packet mirroring IDs"
  value = {
    for region, mirroring in google_compute_packet_mirroring.packet_mirroring : region => mirroring.id
  }
}

output "packet_mirroring_names" {
  description = "Map of region to packet mirroring names"
  value = {
    for region, mirroring in google_compute_packet_mirroring.packet_mirroring : region => mirroring.name
  }
}
