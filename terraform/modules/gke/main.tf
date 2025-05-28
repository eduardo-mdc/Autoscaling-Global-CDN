# GKE module with Hot/Cold cluster support

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
  location = var.region  # Regional cluster

  # Use VPC-native cluster
  networking_mode = "VPC_NATIVE"
  network         = var.network_self_link
  subnetwork      = var.subnet_self_link

  # We'll create a separately managed node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Private cluster configuration
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

  # Binary authorization
  binary_authorization {
    evaluation_mode = "DISABLED"
  }

  # Workload identity for GKE
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  # Enable more monitoring for hot clusters
  dynamic "monitoring_config" {
    for_each = var.cluster_type == "hot" ? [1] : []
    content {
      enable_components = ["SYSTEM_COMPONENTS", "APISERVER", "CONTROLLER_MANAGER", "SCHEDULER"]
    }
  }

  # Enable more logging for hot clusters
  dynamic "logging_config" {
    for_each = var.cluster_type == "hot" ? [1] : []
    content {
      enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS", "APISERVER"]
    }
  }



  # Cluster addons - vary by cluster type
  addons_config {
    http_load_balancing {
      disabled = false
    }

    network_policy_config {
      disabled = false
    }

    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  # Cluster-level labels for identification
  resource_labels = {
    cluster_type = var.cluster_type
    region       = var.region
    environment  = "production"
  }

  depends_on = [
    google_project_service.container_api,
    google_project_service.compute_api
  ]
}

# Create node pool with hot/cold-aware autoscaling
resource "google_container_node_pool" "primary" {
  name       = "${var.project_name}-node-pool-${var.region}-${var.cluster_type}"
  location   = var.region
  cluster    = google_container_cluster.cluster.id

  # Initial node count - 0 for cold clusters
  initial_node_count = var.initial_nodes

  # Autoscaling configuration - different for hot/cold
  autoscaling {
    total_min_node_count = var.min_nodes  # 0 for cold, 2+ for hot
    total_max_node_count = var.max_nodes  # Higher limit for hot

    location_policy = "ANY"  # Distribute across zones
  }

  # Node management - more aggressive for cold clusters
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = var.cluster_type == "hot" ? 2 : 1
    max_unavailable = 0
    strategy        = "SURGE"
  }

  # Node configuration
  node_config {
    image_type   = "COS_CONTAINERD"
    machine_type = var.node_machine_type
    disk_size_gb = var.node_disk_size_gb
    disk_type    = var.node_disk_type

    # Use spot instances for cold clusters (cheaper than preemptible)
    spot = var.cluster_type == "cold" ? true : false

    # Labels and tags
    labels = {
      app          = var.project_name
      region       = var.region
      cluster_type = var.cluster_type
    }

    tags = [
      "${var.project_name}-node",
      "gke-${var.region}",
      "cluster-${var.cluster_type}"
    ]

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload identity on nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Shielded instance config
    shielded_instance_config {
      enable_secure_boot          = false
      enable_integrity_monitoring = true
    }

    # Taint cold cluster nodes to prevent scheduling until needed
    dynamic "taint" {
      for_each = var.cluster_type == "cold" ? [1] : []
      content {
        key    = "cluster-type"
        value  = "cold"
        effect = "NO_SCHEDULE"
      }
    }
  }

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      node_config[0].resource_labels,
      node_config[0].kubelet_config,
      initial_node_count
    ]
  }

  # Timeouts
  timeouts {
    create = var.cluster_type == "hot" ? "45m" : "30m"
    update = "30m"
    delete = "30m"
  }
}