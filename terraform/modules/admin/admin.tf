# terraform/modules/admin/main.tf - Admin Module with Webapp Endpoint

# Enable required APIs
resource "google_project_service" "compute_api" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "dns_api" {
  service            = "dns.googleapis.com"
  disable_on_destroy = false
}

# Create dedicated admin VPC
resource "google_compute_network" "admin_vpc" {
  name                    = "${var.project_name}-admin-vpc"
  auto_create_subnetworks = false
  description             = "VPC network for ${var.project_name} admin"

  depends_on = [google_project_service.compute_api]
}

# Admin subnet
resource "google_compute_subnetwork" "admin_subnet" {
  name          = "${var.project_name}-admin-subnet"
  region        = var.region
  network       = google_compute_network.admin_vpc.id
  ip_cidr_range = var.admin_subnet_cidr
  description   = "Subnet for ${var.project_name} admin"

  # Enable Google private access
  private_ip_google_access = true
}

# Static IP for admin VM (direct SSH access)
resource "google_compute_address" "admin_ip" {
  name         = "${var.project_name}-admin-ip"
  region       = var.region
  address_type = "EXTERNAL"
  description  = "Static IP for admin VM"
}

# Global static IP for admin webapp
resource "google_compute_global_address" "admin_webapp_ip" {
  name        = "${var.project_name}-admin-webapp-ip"
  description = "Global IP for admin webapp"
  ip_version  = "IPV4"
}

# Admin VM instance
resource "google_compute_instance" "admin" {
  name         = "${var.project_name}-admin"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["admin-vm", "${var.project_name}-admin", "admin-webapp"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = 50
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.admin_subnet.self_link

    access_config {
      nat_ip = google_compute_address.admin_ip.address
    }
  }

  metadata = {
    ssh-keys = "${var.admin_username}:${var.ssh_public_key}"
  }


  service_account {
    # Use default compute service account with cloud platform scope
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  allow_stopping_for_update = true
  deletion_protection       = false

  depends_on = [google_project_service.compute_api]
}

# ============================================================================
# ADMIN WEBAPP LOAD BALANCER SETUP
# ============================================================================

# Health check for admin webapp
resource "google_compute_health_check" "admin_webapp" {
  name               = "${var.project_name}-admin-webapp-health"
  description        = "Health check for admin webapp"
  timeout_sec        = 5
  check_interval_sec = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/health"
  }
}

# Instance group for admin VM
resource "google_compute_instance_group" "admin_group" {
  name        = "${var.project_name}-admin-group"
  zone        = var.zone

  instances = [google_compute_instance.admin.self_link]

  named_port {
    name = "http"
    port = 80
  }
}

# Backend service for admin webapp
resource "google_compute_backend_service" "admin_webapp" {
  name                  = "${var.project_name}-admin-webapp-backend"
  description          = "Backend service for admin webapp"
  protocol             = "HTTP"
  port_name            = "http"
  timeout_sec          = 60
  load_balancing_scheme = "EXTERNAL"

  health_checks = [google_compute_health_check.admin_webapp.id]

  backend {
    group           = google_compute_instance_group.admin_group.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  # Connection draining
  connection_draining_timeout_sec = 60
}

# URL map for admin webapp
resource "google_compute_url_map" "admin_webapp" {
  name            = "${var.project_name}-admin-webapp-url-map"
  description     = "URL map for admin webapp"
  default_service = google_compute_backend_service.admin_webapp.id
}

# HTTP target proxy for admin webapp
resource "google_compute_target_http_proxy" "admin_webapp" {
  name    = "${var.project_name}-admin-webapp-http-proxy"
  url_map = google_compute_url_map.admin_webapp.id
}

# HTTPS target proxy (if domain is provided)
resource "google_compute_managed_ssl_certificate" "admin_webapp" {
  count = var.domain_name != "" ? 1 : 0

  name = "${var.project_name}-admin-webapp-ssl"

  managed {
    domains = ["admin.${var.domain_name}"]
  }

  lifecycle {
    create_before_destroy = true
  }

  timeouts {
    create = "30m"
    delete = "10m"
  }
}

resource "google_compute_target_https_proxy" "admin_webapp" {
  count = var.domain_name != "" ? 1 : 0

  name             = "${var.project_name}-admin-webapp-https-proxy"
  url_map          = google_compute_url_map.admin_webapp.id
  ssl_certificates = [google_compute_managed_ssl_certificate.admin_webapp[0].id]
}

# HTTP forwarding rule
resource "google_compute_global_forwarding_rule" "admin_webapp_http" {
  name       = "${var.project_name}-admin-webapp-http-rule"
  target     = google_compute_target_http_proxy.admin_webapp.id
  port_range = "80"
  ip_address = google_compute_global_address.admin_webapp_ip.address

  labels = {
    service = "admin-webapp"
  }
}

# HTTPS forwarding rule (if SSL enabled)
resource "google_compute_global_forwarding_rule" "admin_webapp_https" {
  count = var.domain_name != "" ? 1 : 0

  name       = "${var.project_name}-admin-webapp-https-rule"
  target     = google_compute_target_https_proxy.admin_webapp[0].id
  port_range = "443"
  ip_address = google_compute_global_address.admin_webapp_ip.address

  labels = {
    service = "admin-webapp"
    ssl     = "managed"
  }
}

# DNS record for admin subdomain (if domain provided)
resource "google_dns_record_set" "admin_webapp" {
  count = var.domain_name != "" ? 1 : 0

  name         = "admin.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_zone_name
  rrdatas      = [google_compute_global_address.admin_webapp_ip.address]

  depends_on = [google_project_service.dns_api]
}

# ============================================================================
# FIREWALL RULES
# ============================================================================

# SSH access to admin VM
resource "google_compute_firewall" "admin_ssh" {
  name    = "${var.project_name}-admin-ssh"
  network = google_compute_network.admin_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_ranges
  target_tags   = ["admin-vm"]
  priority      = 1000
}

# HTTP access for admin webapp (from load balancer)
resource "google_compute_firewall" "admin_webapp_http" {
  name    = "${var.project_name}-admin-webapp-http"
  network = google_compute_network.admin_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "8080"]
  }

  # Allow from Google load balancer IP ranges
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]
  target_tags = ["admin-webapp"]
  priority    = 1000
}

# Allow health checks
resource "google_compute_firewall" "admin_webapp_health" {
  name    = "${var.project_name}-admin-webapp-health"
  network = google_compute_network.admin_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # Google Cloud health check IP ranges
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]
  target_tags = ["admin-webapp"]
  priority    = 500
}

# Allow outbound internet access
resource "google_compute_firewall" "admin_egress" {
  name      = "${var.project_name}-admin-egress"
  network   = google_compute_network.admin_vpc.name
  direction = "EGRESS"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "22", "53"]
  }

  allow {
    protocol = "udp"
    ports    = ["53"]
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags       = ["admin-vm", "admin-webapp"]
  priority          = 1000
}

# Allow ingress from GKE master subnets (dynamic calculation)
resource "google_compute_firewall" "admin_allow_from_gke_masters" {
  name    = "${var.project_name}-admin-allow-gke-masters"
  network = google_compute_network.admin_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }

  # Calculate master CIDRs based on region numbers
  source_ranges = [
    for region_num in values(var.region_numbers) :
    "172.16.${region_num}.0/28"
  ]

  target_tags = ["admin-vm"]
  priority    = 1000
}