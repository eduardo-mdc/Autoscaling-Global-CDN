# Admin VM module with fixed SSH key configuration

# Enable required APIs
resource "google_project_service" "compute_api" {
  service = "compute.googleapis.com"
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
  tags         = ["admin-vm", "${var.project_name}-admin"]

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

  # Minimal startup script - just to ensure SSH access
  metadata = {
    ssh-keys = "${var.admin_username}:${var.ssh_public_key}"
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  depends_on = [google_project_service.compute_api]
}

# Create static IP for admin VM
resource "google_compute_address" "admin_ip" {
  name         = "${var.project_name}-admin-ip"
  region       = var.region
  address_type = "EXTERNAL"
}

# Create firewall rule for SSH access to admin VM
resource "google_compute_firewall" "admin_ssh" {
  name    = "${var.project_name}-admin-ssh"
  network = google_compute_network.admin_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Restrict to specific IP ranges if needed in production
  source_ranges = var.allowed_ssh_ranges
  target_tags   = ["admin-vm"]
}

# Create VPC peering connections from admin VPC to all other VPCs
resource "google_compute_network_peering" "admin_to_region" {
  for_each = { for idx, link in var.vpc_network_links : idx => link }

  name         = "${var.project_name}-admin-to-region-${each.key}"
  network      = google_compute_network.admin_vpc.self_link
  peer_network = each.value

  # Share custom routes
  export_custom_routes = true
  import_custom_routes = true
}