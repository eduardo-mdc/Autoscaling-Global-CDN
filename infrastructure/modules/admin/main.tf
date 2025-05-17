// Try to find existing SSH key
data "digitalocean_ssh_keys" "existing" {}

locals {
  // Read the public key from file
  public_key = file(var.ssh_public_key_path)

  // Check if a key with the same public key content already exists
  existing_key = [
    for key in data.digitalocean_ssh_keys.existing.ssh_keys :
    key if key.public_key == local.public_key
  ]

  // Use existing key if found, otherwise create a new one
  use_existing_key = length(local.existing_key) > 0
  key_fingerprint = local.use_existing_key ? local.existing_key[0].fingerprint : digitalocean_ssh_key.admin_key[0].fingerprint
}

// Create SSH key only if it doesn't already exist
resource "digitalocean_ssh_key" "admin_key" {
  count      = local.use_existing_key ? 0 : 1
  name       = "${var.project_name}-admin-key"
  public_key = local.public_key
}

// Create firewall for admin access
resource "digitalocean_firewall" "admin_fw" {
  name = "${var.project_name}-admin-fw"

  // Allow SSH from anywhere (you might want to restrict this in production)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
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

// Create the admin droplet
resource "digitalocean_droplet" "admin" {
  name       = "${var.project_name}-admin"
  region     = var.region
  size       = var.droplet_size
  image      = "ubuntu-20-04-x64"  // Ubuntu 20.04 LTS
  vpc_uuid   = var.vpc_id
  ssh_keys   = [local.key_fingerprint]
  monitoring = true
  tags       = [for key, value in var.tags : "${key}:${value}"]

  user_data = <<-EOF
    #!/bin/bash
    # Update system packages
    apt-get update
    apt-get upgrade -y
    
    # Install required tools
    apt-get install -y docker.io curl apt-transport-https ca-certificates software-properties-common unzip jq
    
    # Set up Docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ${var.admin_username}
    
    # Install doctl (Digital Ocean CLI)
    cd /tmp
    curl -sL https://github.com/digitalocean/doctl/releases/download/v1.78.0/doctl-1.78.0-linux-amd64.tar.gz | tar -xzv
    mv doctl /usr/local/bin
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
    
    # Create admin user script
    cat << 'SCRIPT' > /home/${var.admin_username}/manage-container-apps.sh
    #!/bin/bash
    echo "Digital Ocean container management script"
    # Can be expanded with custom management scripts
    SCRIPT
    
    chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/manage-container-apps.sh
    chmod +x /home/${var.admin_username}/manage-container-apps.sh
  EOF
}

// Create a reserved IP for the admin droplet
resource "digitalocean_reserved_ip" "admin_ip" {
  region = var.region
  droplet_id = digitalocean_droplet.admin.id
}