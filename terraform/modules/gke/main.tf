# GKE module - Kubernetes cluster with global HTTP load balancing support (Final Fix)

# Enable required APIs
resource "google_project_service" "container_api" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute_api" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# Create GKE cluster
resource "google_container_cluster" "cluster" {
  name     = "${var.project_name}-gke-${var.region}"
  location = var.region  # Use regional cluster for high availability

  # Use VPC-native cluster
  networking_mode = "VPC_NATIVE"
  network         = var.network_self_link
  subnetwork      = var.subnet_self_link

  # We'll create a separately managed node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Private cluster configuration - control plane has private IP
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.${var.region_number}.0/28"
  }

  # IP allocation policy for VPC-native
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.${100 + var.region_number}.0.0/16"
    services_ipv4_cidr_block = "10.${200 + var.region_number}.0.0/16"
  }

  # Master authorized networks - only allow from admin VM
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.admin_cidr
      display_name = "Admin VM"
    }
  }

  # Network policy for enhanced security
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Binary authorization (optional, for production)
  binary_authorization {
    evaluation_mode = "DISABLED"
  }

  # Workload identity for GKE
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Cluster addons
  addons_config {
    http_load_balancing {
      disabled = false  # Enable HTTP load balancing
    }

    network_policy_config {
      disabled = false
    }

    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  # Depend on the APIs being enabled
  depends_on = [
    google_project_service.container_api,
    google_project_service.compute_api
  ]
}

# Create node pool with autoscaling
resource "google_container_node_pool" "primary" {
  name       = "${var.project_name}-node-pool-${var.region}"
  location   = var.region
  cluster    = google_container_cluster.cluster.id

  node_locations = null # Can use any zone in the region
  initial_node_count = 1

  # Autoscaling configuration
  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Upgrade settings - add explicit configuration
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  # Node configuration
  node_config {
    image_type   = "COS_CONTAINERD"
    machine_type = var.node_machine_type
    disk_size_gb = var.node_disk_size_gb
    disk_type    = var.node_disk_type

    # Labels and tags
    labels = {
      app = var.project_name
    }

    tags = ["${var.project_name}-node", "gke-${var.region}"]

    # OAuth scopes - simplified to standard set
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload identity on nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Enable shielded nodes for enhanced security
    shielded_instance_config {
      enable_secure_boot          = false
      enable_integrity_monitoring = true
    }


  }
  # Lifecycle management - prevent unnecessary node pool updates
  lifecycle {
    ignore_changes = [
      node_config[0].resource_labels,
      node_config[0].kubelet_config
    ]
  }


  # Add timeout settings
  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}