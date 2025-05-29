# modules/bastion/main.tf
# Private bastion host module for accessing GKE clusters within regional VPCs
# Only accessible via admin VM (no public IP)

# Enable required APIs
resource "google_project_service" "compute_api" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# Create private bastion VM instance (no external IP)
resource "google_compute_instance" "bastion" {
  name         = "${var.project_name}-bastion-${var.region}"
  machine_type = var.machine_type
  zone         = "${var.region}-a"  # Use first zone in region

  tags = ["bastion-host", "${var.project_name}-bastion-${var.region}"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = var.subnet_self_link
    # NO access_config = private IP only
  }

  metadata = {
    ssh-keys = "${var.admin_username}:${var.ssh_public_key}"
  }

  # Minimal startup script - Ansible will handle the rest
  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    apt-get update && apt-get upgrade -y

    # Install Python for Ansible
    apt-get install -y python3 python3-pip

    # Log completion
    echo "Bastion minimal startup completed at $(date)" > /var/log/bastion-startup-completed.log
  EOF

  service_account {
    # Use default compute service account with necessary scopes
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  allow_stopping_for_update = true
  deletion_protection = false
  depends_on = [google_project_service.compute_api]
}

# Create firewall rule for SSH access from admin VM only
resource "google_compute_firewall" "bastion_ssh_from_admin" {
  name    = "${var.project_name}-bastion-ssh-from-admin-${var.region}"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Only allow SSH from admin VM CIDR
  source_ranges = [var.admin_cidr]
  target_tags   = ["bastion-host"]
  priority      = 1000
}