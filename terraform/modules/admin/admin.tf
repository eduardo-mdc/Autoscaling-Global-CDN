# Admin VM module - Remove the VPC peering (move to main.tf)

# Enable required APIs
resource "google_project_service" "compute_api" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# Create a dedicated VPC for admin access
resource "google_compute_network" "admin_vpc" {
  name                    = "${var.project_name}-admin-vpc"
  auto_create_subnetworks = false
  description             = "VPC network for ${var.project_name} admin"
}

# Create admin subnet
resource "google_compute_subnetwork" "admin_subnet" {
  name          = "${var.project_name}-admin-subnet"
  region        = var.region
  network       = google_compute_network.admin_vpc.id
  ip_cidr_range = "10.250.0.0/24"
  description   = "Subnet for ${var.project_name} admin in ${var.region}"

  # Enable Google private access
  private_ip_google_access = true
}

# Create admin VM instance
resource "google_compute_instance" "admin" {
  name         = "${var.project_name}-admin"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["admin-vm", "${var.project_name}-admin"]

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

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e
    apt-get update && apt-get upgrade -y
    apt-get install -y python3 python3-pip
    echo "Startup script completed at $(date)" > /var/log/startup-script-completed.log
  EOF

  service_account {
    scopes = ["cloud-platform"]
  }

  deletion_protection = false
  depends_on = [google_project_service.compute_api]
}

# Create static IP for admin VM
resource "google_compute_address" "admin_ip" {
  name         = "${var.project_name}-admin-ip"
  region       = var.region
  address_type = "EXTERNAL"
}


# Calculate master CIDRs based on region numbers
locals {
  master_cidrs = [
    for region_num in values(var.region_numbers) :
    "172.16.${region_num}.0/28"
  ]
}

# Allow ingress from GKE master subnets to admin VM (dynamic)
resource "google_compute_firewall" "admin_allow_from_gke_masters" {
  name    = "${var.project_name}-admin-allow-from-gke-masters"
  network = google_compute_network.admin_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }

  # Use calculated master CIDRs
  source_ranges = local.master_cidrs

  target_tags = ["admin-vm"]
  priority = 1000
}

# Create firewall rule for SSH access to admin VM
resource "google_compute_firewall" "admin_ssh" {
  name    = "${var.project_name}-admin-ssh"
  network = google_compute_network.admin_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_ranges
  target_tags   = ["admin-vm"]
}

# Create firewall rule for HTTP/HTTPS access to admin VM
resource "google_compute_firewall" "admin_https" {
  name    = "${var.project_name}-admin-https"
  network = google_compute_network.admin_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  # IAP's IP range for TCP forwarding
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["admin-vm"]
}

# IAP web configuration for admin VM
resource "google_iap_web_backend_service_iam_binding" "admin_iap_binding" {
  project = var.project_id
  web_backend_service = google_compute_backend_service.admin_backend.name
  role    = "roles/iap.httpsResourceAccessor"

  members = var.iap_members
}

resource "google_compute_health_check" "admin_health_check" {
  name               = "${var.project_name}-admin-health-check"
  check_interval_sec = 5
  timeout_sec        = 5

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

# Create backend service for admin VM
resource "google_compute_backend_service" "admin_backend" {
  name        = "${var.project_name}-admin-backend"
  port_name   = "http"
  protocol    = "HTTP"
  timeout_sec = 30
  health_checks = [google_compute_health_check.admin_health_check.id]

  backend {
    group = google_compute_instance_group.admin_group.self_link
  }

  iap {
    oauth2_client_id     = var.oauth_client_id
    oauth2_client_secret = var.oauth_client_secret
  }
}

# Create instance group for admin VM
resource "google_compute_instance_group" "admin_group" {
  name      = "${var.project_name}-admin-group"
  zone      = var.zone
  instances = [google_compute_instance.admin.self_link]

  # Add named port configuration
  named_port {
    name = "http"
    port = 80
  }
}

# Create URL map for admin service
resource "google_compute_url_map" "admin_url_map" {
  name            = "${var.project_name}-admin-url-map"
  default_service = google_compute_backend_service.admin_backend.id
}

# Create HTTP proxy for admin service
resource "google_compute_target_http_proxy" "admin_http_proxy" {
  name    = "${var.project_name}-admin-http-proxy"
  url_map = google_compute_url_map.admin_url_map.id
}

# Create global IP address for admin frontend
resource "google_compute_global_address" "admin_ip" {
  name         = "${var.project_name}-admin-global-ip"
  description  = "Global IP for ${var.project_name} admin frontend"
}

# Create HTTP forwarding rule
resource "google_compute_global_forwarding_rule" "admin_http" {
  name       = "${var.project_name}-admin-http-rule"
  target     = google_compute_target_http_proxy.admin_http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.admin_ip.address
}

# Create SSL certificate (self-managed or managed)
resource "google_compute_managed_ssl_certificate" "admin_cert" {
  name = "${var.project_name}-admin-cert"

  managed {
    domains = ["admin.${var.domain_name}"]
  }
}

# Create HTTPS proxy with SSL certificate
resource "google_compute_target_https_proxy" "admin_https_proxy" {
  name             = "${var.project_name}-admin-https-proxy"
  url_map          = google_compute_url_map.admin_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.admin_cert.id]
}

# Create HTTPS forwarding rule
resource "google_compute_global_forwarding_rule" "admin_forward_https" {
  name       = "${var.project_name}-admin-https-rule"
  target     = google_compute_target_https_proxy.admin_https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.admin_ip.address
}

# Create A record for admin subdomain pointing to the global IP
resource "google_dns_record_set" "admin_record" {
  name         = "admin.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = "${var.project_name}-zone"


  rrdatas = [google_compute_global_address.admin_ip.address]
}