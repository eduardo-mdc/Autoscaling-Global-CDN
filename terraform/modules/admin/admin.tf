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