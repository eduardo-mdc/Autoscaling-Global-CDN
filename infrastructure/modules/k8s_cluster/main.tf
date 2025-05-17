# Create the Kapsule cluster in a single region
resource "random_id" "suffix" {
  byte_length = 4
}


resource "scaleway_k8s_cluster" "this" {
  name                    = "${var.project_name}-k8s-sg-${var.region}-${random_id.suffix.hex}"
  project_id         = var.project_id
  region             = var.region
  version            = var.k8s_version
  cni                = var.cni
  private_network_id = var.vpc_id
  delete_additional_resources = true



  # Tags for better management
  tags = ["terraform", var.project_name, "k8s", var.region]
}

# Security group for Kubernetes nodes
resource "scaleway_instance_security_group" "k8s" {
  name                    = "${var.project_name}-k8s-sg-${var.region}"
  inbound_default_policy  = "drop"    # Default deny incoming
  outbound_default_policy = "accept"  # Default allow outgoing

  # Allow admin server access to K8s API
  dynamic "inbound_rule" {
    for_each = var.admin_server_ip != "" ? [1] : []
    content {
      action   = "accept"
      port     = 6443  # Kubernetes API port
      ip       = var.admin_server_ip
      protocol = "TCP"
    }
  }

  # Allow all required cluster internal traffic between nodes
  inbound_rule {
    action   = "accept"
    port_range = "1-65535"
    ip_range = var.vpc_cidr
    protocol = "TCP"
  }

  inbound_rule {
    action   = "accept"
    port_range = "1-65535"
    ip_range = var.vpc_cidr
    protocol = "UDP"
  }

  # Allow access to K8s services
  inbound_rule {
    action   = "accept"
    port     = 80
    ip_range = "0.0.0.0/0"
    protocol = "TCP"
  }

  inbound_rule {
    action   = "accept"
    port     = 443
    ip_range = "0.0.0.0/0"
    protocol = "TCP"
  }

  tags = ["terraform", "${var.project_name}", "k8s", var.region]
}

# Create an autoscaling pool in that cluster
resource "scaleway_k8s_pool" "this" {
  cluster_id = scaleway_k8s_cluster.this.id
  name       = "default-pool-${var.region}"
  node_type  = var.node_type

  size       = var.size
  max_size   = var.max_size
  min_size   = var.min_size

  autoscaling        = true
  autohealing        = true
  container_runtime  = "containerd"
  # Don't assign public IPs to nodes
  placement_group_id = null
  public_ip_disabled = true

}

# Generate kubeconfig for admin access
data "scaleway_k8s_cluster" "kubeconfig" {
  cluster_id = scaleway_k8s_cluster.this.id
  depends_on = [scaleway_k8s_pool.this]
}

resource "local_file" "kubeconfig" {
  content  = data.scaleway_k8s_cluster.kubeconfig.kubeconfig[0].config_file
  filename = "${path.module}/kubeconfig-${var.region}.yaml"
  file_permission = "0600"
}