// Just use the default VPC that already exists
data "digitalocean_vpc" "default" {
  name = "${var.project_name}-vpc-${var.region}"
}

// Create a firewall for allowing HTTP traffic
resource "digitalocean_firewall" "web" {
  name = "${var.project_name}-web-fw-${var.region}"

  // Use the default VPC ID
  droplet_ids = []

  // Allow HTTP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  // Allow HTTPS
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  // Default outbound rules - allow all traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}