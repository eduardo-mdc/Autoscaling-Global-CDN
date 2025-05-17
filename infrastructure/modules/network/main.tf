# Network module for Scaleway

resource "scaleway_vpc" "main" {
  name = "${var.project_name}-vpc-${var.region}"
  tags = ["terraform", "${var.project_name}"]
}

resource "scaleway_vpc_private_network" "main" {
  name   = "${var.project_name}-private-network-${var.region}"
  vpc_id = scaleway_vpc.main.id
  tags   = ["terraform", "${var.project_name}"]
}

# Security group to allow HTTP/HTTPS traffic
resource "scaleway_instance_security_group" "web" {
  name                    = "${var.project_name}-web-sg-${var.region}"
  inbound_default_policy  = "drop"  # Default deny incoming
  outbound_default_policy = "accept" # Default allow outgoing

  # Allow HTTP traffic
  inbound_rule {
    action   = "accept"
    port     = 80
    ip_range = "0.0.0.0/0"
    protocol = "TCP"
  }

  # Allow HTTPS traffic
  inbound_rule {
    action   = "accept"
    port     = 443
    ip_range = "0.0.0.0/0"
    protocol = "TCP"
  }

  tags = ["terraform", "${var.project_name}", "web"]
}