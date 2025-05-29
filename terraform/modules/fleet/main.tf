# terraform/modules/fleet/main.tf
# GKE Fleet for Multi-Cluster Ingress

# Enable required APIs
resource "google_project_service" "fleet_api" {
  service            = "gkehub.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "mci_api" {
  service            = "multiclusteringress.googleapis.com"
  disable_on_destroy = false
}

# Register config cluster membership
resource "google_gke_hub_membership" "config_cluster" {
  membership_id = "${var.project_name}-config-membership"

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/projects/${var.project_id}/locations/${var.config_cluster_region}/clusters/${var.project_name}-gke-${var.config_cluster_region}"
    }
  }

  depends_on = [google_project_service.fleet_api]
}

# Register member cluster memberships
resource "google_gke_hub_membership" "member_clusters" {
  for_each = toset(var.member_cluster_regions)

  membership_id = "${var.project_name}-${each.value}-membership"

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/projects/${var.project_id}/locations/${each.value}/clusters/${var.project_name}-gke-${each.value}"
    }
  }

  depends_on = [google_project_service.fleet_api]
}

# Enable Multi-Cluster Ingress feature
resource "google_gke_hub_feature" "mci" {
  name     = "multiclusteringress"
  location = "global"

  spec {
    multiclusteringress {
      config_membership = google_gke_hub_membership.config_cluster.id
    }
  }

  depends_on = [
    google_project_service.mci_api,
    google_gke_hub_membership.config_cluster
  ]
}

# Reserve global IP for MCI
resource "google_compute_global_address" "mci_ip" {
  name         = "${var.project_name}-mci-global-ip"
  description  = "Global IP for Multi-Cluster Ingress"
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}

# DNS Zone for domain (if provided)
resource "google_dns_managed_zone" "mci_zone" {
  count = var.domain_name != "" ? 1 : 0

  name        = "${var.project_name}-mci-zone"
  dns_name    = "${var.domain_name}."
  description = "DNS zone for ${var.project_name} Multi-Cluster Ingress"
  visibility  = "public"

  dnssec_config {
    state         = "on"
    non_existence = "nsec3"
  }
}

# A record for root domain
resource "google_dns_record_set" "mci_root" {
  count = var.domain_name != "" ? 1 : 0

  name         = "${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.mci_zone[0].name
  rrdatas      = [google_compute_global_address.mci_ip.address]
}

# A record for www subdomain
resource "google_dns_record_set" "mci_www" {
  count = var.domain_name != "" ? 1 : 0

  name         = "www.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.mci_zone[0].name
  rrdatas      = [google_compute_global_address.mci_ip.address]
}