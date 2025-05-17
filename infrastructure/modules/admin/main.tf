# Admin server module for Scaleway
# This creates an admin instance with access to all VPCs

resource "scaleway_instance_security_group" "admin" {
  name                    = "${var.project_name}-admin-sg"
  inbound_default_policy  = "drop"     # Default deny incoming
  outbound_default_policy = "accept"   # Default allow outgoing

  # Allow SSH access
  inbound_rule {
    action   = "accept"
    port     = 22
    ip_range = var.admin_allowed_ip
    protocol = "TCP"
  }

  # Allow HTTP for admin dashboard (if needed)
  inbound_rule {
    action   = "accept"
    port     = 80
    ip_range = var.admin_allowed_ip
    protocol = "TCP"
  }

  # Allow HTTPS for admin dashboard (if needed)
  inbound_rule {
    action   = "accept"
    port     = 443
    ip_range = var.admin_allowed_ip
    protocol = "TCP"
  }

  tags = ["terraform", "${var.project_name}", "admin"]
}

# Admin server instance in Paris region
resource "scaleway_instance_server" "admin" {
  name              = "${var.project_name}-admin"
  type              = var.instance_type
  image             = var.instance_image
  security_group_id = scaleway_instance_security_group.admin.id
  enable_ipv6       = false
  routed_ip_enabled = true
  enable_dynamic_ip = true
  tags              = ["terraform", "${var.project_name}", "admin"]

  # Connect to the Paris private network
  private_network {
    pn_id = var.private_network_id
  }

  root_volume {
    size_in_gb = var.root_volume_size
  }

  user_data = {
    cloud-init = templatefile("${path.module}/cloud-init.yml", {
      username = var.admin_username
      ssh_public_key = var.ssh_public_key
    })
  }
}

# Generate kubeconfig files for all clusters
resource "local_file" "kubeconfig_par" {
  content         = var.kubeconfig_paris
  filename        = "${path.module}/generated/kubeconfig_paris.yaml"
  file_permission = "0600"

  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/generated"
  }
}

resource "local_file" "kubeconfig_ams" {
  content         = var.kubeconfig_amsterdam
  filename        = "${path.module}/generated/kubeconfig_amsterdam.yaml"
  file_permission = "0600"
}

resource "local_file" "kubeconfig_waw" {
  content         = var.kubeconfig_warsaw
  filename        = "${path.module}/generated/kubeconfig_warsaw.yaml"
  file_permission = "0600"
}

# Provision the admin server with necessary tools
resource "null_resource" "admin_provisioner" {
  depends_on = [
    scaleway_instance_server.admin,
    local_file.kubeconfig_par,
    local_file.kubeconfig_ams,
    local_file.kubeconfig_waw
  ]

  # Copy kubeconfig files to the admin server
  provisioner "file" {
    source      = "${path.module}/generated/"
    destination = "/home/${var.admin_username}/.kube/"

    connection {
      type        = "ssh"
      user        = var.admin_username
      host        = scaleway_instance_server.admin.public_ip
      private_key = file(var.ssh_private_key_path)
    }
  }

  # Install necessary tools on the admin server
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/${var.admin_username}/.kube/",
      "sudo apt-get update",
      "sudo apt-get install -y kubectl docker.io jq curl",
      "echo 'export KUBECONFIG=/home/${var.admin_username}/.kube/kubeconfig_paris.yaml:/home/${var.admin_username}/.kube/kubeconfig_amsterdam.yaml:/home/${var.admin_username}/.kube/kubeconfig_warsaw.yaml' >> /home/${var.admin_username}/.bashrc",
      "curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash",
      "chmod 600 /home/${var.admin_username}/.kube/*"
    ]

    connection {
      type        = "ssh"
      user        = var.admin_username
      host        = scaleway_instance_server.admin.public_ip
      private_key = file(var.ssh_private_key_path)
    }
  }
}