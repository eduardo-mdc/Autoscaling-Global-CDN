# Network module for creating isolated VPC networks in each region

# Create VPC network
resource "google_compute_network" "vpc" {
  name                    = "${var.project_name}-vpc-${var.region}"
  auto_create_subnetworks = false
  description             = "VPC network for ${var.project_name} in ${var.region}"
}

# Create subnet in the VPC
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_name}-subnet-${var.region}"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.${var.region_number}.0.0/20"
  description   = "Subnet for ${var.project_name} in ${var.region}"

  # Enable private Google access for GKE nodes
  private_ip_google_access = true

  # Enable flow logs for security monitoring
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Allow internet egress for HTTPS/HTTP (kubectl, APIs)
resource "google_compute_firewall" "allow_internet_egress" {
  name    = "${var.project_name}-allow-internet-egress-${var.region}"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443", "80"]  # HTTPS and HTTP
  }

  direction = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]
  priority = 1000
}

# Allow egress to admin VPC (return traffic to admin VM)
resource "google_compute_firewall" "allow_egress_to_admin" {
  name    = "${var.project_name}-allow-egress-to-admin-${var.region}"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }

  direction = "EGRESS"
  destination_ranges = [var.admin_cidr]
  priority = 1000
}

# Allow internal traffic within region
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.project_name}-allow-internal-${var.region}"
  network = google_compute_network.vpc.name

  allow {
    protocol = "all"
  }

  # Allow traffic within the subnet
  source_ranges = [google_compute_subnetwork.subnet.ip_cidr_range]
  priority = 1000
}

# Allow traffic from admin VM
resource "google_compute_firewall" "allow_from_admin" {
  name    = "${var.project_name}-allow-from-admin-${var.region}"
  network = google_compute_network.vpc.name

  allow {
    protocol = "all"
  }

  # Admin VM CIDR range
  source_ranges = [var.admin_cidr]
  priority = 1000
}

# Block inter-region traffic (maintain isolation)
resource "google_compute_firewall" "block_inter_region" {
  name    = "${var.project_name}-block-inter-region-${var.region}"
  network = google_compute_network.vpc.name

  # Deny all traffic from other regions' subnets
  deny {
    protocol = "all"
  }

  # Source ranges include all other region subnets
  source_ranges = var.other_region_cidrs

  # Target is this region's subnet
  destination_ranges = [google_compute_subnetwork.subnet.ip_cidr_range]

  # Lower priority than the admin allow rule
  priority = 2000
}

# NAT gateway for outbound internet access from private instances
resource "google_compute_router" "router" {
  name    = "${var.project_name}-router-${var.region}"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.project_name}-nat-${var.region}"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
