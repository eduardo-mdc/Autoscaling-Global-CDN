# Configure providers
provider "google" {
  project     = var.project_id
  credentials = file(var.credentials_file)
  region      = var.regions[0]
}

provider "google-beta" {
  project     = var.project_id
  credentials = file(var.credentials_file)
  region      = var.regions[0]
}
# Local values
locals {
  region_numbers = {
    for idx, region in var.regions : region => idx + 1
  }

  region_cidrs = {
    for region in var.regions :
    region => "10.${local.region_numbers[region]}.0.0/20"
  }

  other_region_cidrs = {
    for region in var.regions :
    region => [
      for r, cidr in local.region_cidrs :
      cidr if r != region
    ]
  }

  admin_cidr = "10.250.0.0/24"
  hot_regions = toset(var.hot_regions)
  cold_regions = toset(var.cold_regions)
}

# ============================================================================
# PHASE 1: CORE INFRASTRUCTURE (No interdependencies)
# ============================================================================

# 1.1 Admin VPC and VM (independent)
module "admin" {
  source = "./modules/admin"

  project_id     = var.project_id
  project_name   = var.project_name
  region         = var.regions[0]
  zone           = var.zones[var.regions[0]]
  machine_type   = var.admin_machine_type
  admin_username = var.admin_username
  ssh_public_key = file(var.ssh_public_key_path)

  # Pass region numbers for firewall rules
  region_numbers = local.region_numbers
  all_regions    = var.regions

  # Admin webapp configuration
  domain_name    = var.domain_name
  dns_zone_name  = var.domain_name != "" ? "${var.project_name}-zone" : ""

  # Security
  allowed_ssh_ranges = var.admin_allowed_ips

  # Use local admin CIDR to avoid circular dependency
  admin_subnet_cidr = local.admin_cidr
}

# 1.2 Storage buckets (independent)
module "storage" {
  source = "./modules/storage"

  project_id   = var.project_id
  project_name = var.project_name
  regions      = var.regions

  # Storage configuration
  master_bucket_location           = var.master_bucket_location
  environment                     = var.environment
  enable_versioning               = var.enable_storage_versioning
  enable_regional_versioning      = var.enable_regional_storage_versioning
  enable_lifecycle_management     = var.enable_storage_lifecycle
  enable_cache_lifecycle_management = var.enable_cache_lifecycle
  enable_bucket_notifications     = var.enable_bucket_notifications
  public_access_prevention        = var.storage_public_access_prevention
  force_destroy                   = var.storage_force_destroy
}

# ============================================================================
# PHASE 2: NETWORKING (Depends only on admin)
# ============================================================================

# 2.1 Regional VPCs (depends only on admin CIDR)
module "network" {
  source   = "./modules/network"
  for_each = local.region_numbers

  project_id            = var.project_id
  project_name          = var.project_name
  region                = each.key
  region_number         = each.value
  admin_cidr            = local.admin_cidr  # Use local value
  other_region_cidrs    = local.other_region_cidrs[each.key]
}

# 2.2 VPC Peering (admin to regions)
resource "google_compute_network_peering" "admin_to_region" {
  for_each = local.region_numbers

  name         = "${var.project_name}-admin-to-${each.key}"
  network      = module.admin.admin_vpc_self_link
  peer_network = module.network[each.key].network_self_link

  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "region_to_admin" {
  for_each = local.region_numbers

  name         = "${var.project_name}-${each.key}-to-admin"
  network      = module.network[each.key].network_self_link
  peer_network = module.admin.admin_vpc_self_link

  export_custom_routes = true
  import_custom_routes = true
}

# ============================================================================
# PHASE 3: HOT/COLD KUBERNETES CLUSTERS
# ============================================================================

# Hot GKE Clusters (always active)
module "gke_hot" {
  source   = "./modules/gke"
  for_each = {
    for region in var.regions : region => local.region_numbers[region]
    if contains(var.hot_regions, region)
  }

  project_id        = var.project_id
  project_name      = var.project_name
  region            = each.key
  region_number     = each.value
  network_self_link = module.network[each.key].network_self_link
  subnet_self_link  = module.network[each.key].subnet_self_link
  admin_cidr        = local.admin_cidr

  initial_nodes     = var.hot_cluster_config.initial_nodes
  min_nodes         = var.hot_cluster_config.min_nodes
  max_nodes         = var.hot_cluster_config.max_nodes
  node_machine_type = var.hot_cluster_config.machine_type
  node_disk_size_gb = var.hot_cluster_config.disk_size_gb
  node_disk_type    = var.hot_cluster_config.disk_type

  cluster_type      = "hot"
  enable_monitoring = true
  enable_logging    = true
}

# Cold GKE Clusters (scaled down by default)
module "gke_cold" {
  source   = "./modules/gke"
  for_each = {
    for region in var.regions : region => local.region_numbers[region]
    if contains(var.cold_regions, region)
  }

  project_id        = var.project_id
  project_name      = var.project_name
  region            = each.key
  region_number     = each.value
  network_self_link = module.network[each.key].network_self_link
  subnet_self_link  = module.network[each.key].subnet_self_link
  admin_cidr        = local.admin_cidr

  initial_nodes     = var.cold_cluster_config.initial_nodes  # 0
  min_nodes         = var.cold_cluster_config.min_nodes      # 0
  max_nodes         = var.cold_cluster_config.max_nodes      # 5
  node_machine_type = var.cold_cluster_config.machine_type
  node_disk_size_gb = var.cold_cluster_config.disk_size_gb
  node_disk_type    = var.cold_cluster_config.disk_type

  cluster_type      = "cold"
  enable_monitoring = false
  enable_logging    = false
}

# 3.2 Bastion hosts (depends on networks)
module "bastion" {
  source   = "./modules/bastion"
  for_each = local.region_numbers

  project_id     = var.project_id
  project_name   = var.project_name
  region         = each.key
  machine_type   = "e2-small"
  admin_username = var.admin_username
  ssh_public_key = file(var.ssh_public_key_path)

  network_name      = module.network[each.key].network_name
  subnet_self_link  = module.network[each.key].subnet_self_link
  admin_cidr        = local.admin_cidr  # Use local value
}

# ============================================================================
# PHASE 4: LOAD BALANCER (Independent, no backend dependencies)
# ============================================================================

# 4.1 Main Load Balancer (independent - backends added later by Ansible)
module "loadbalancer" {
  source = "./modules/loadbalancer"

  project_id   = var.project_id
  project_name = var.project_name
  regions      = var.regions
  domain_name  = var.domain_name

  # SSL and domain configuration
  enable_regional_subdomains = var.enable_regional_subdomains
  enable_caa_records        = var.enable_caa_records
  additional_domains        = var.additional_domains
}


module "admin_webapp" {
  source = "./modules/admin-webapp"

  project_id         = var.project_id
  project_name       = var.project_name
  region            = var.regions[0]
  master_bucket_name = module.storage.master_bucket_name
  container_image   = "gcr.io/${var.project_id}/admin-webapp:latest"
  regions           = var.regions
  admin_iap_members = var.admin_iap_members
}



module "fleet" {
  source = "./modules/fleet"

  project_id               = var.project_id
  project_name             = var.project_name
  config_cluster_region    = var.hot_regions[0]  # First hot region is config cluster
  member_cluster_regions   = concat(
    slice(var.hot_regions, 1, length(var.hot_regions)),  # Other hot regions
    var.cold_regions  # All cold regions
  )
  domain_name              = var.domain_name

  # Ensure all clusters are created first
  depends_on = [module.gke_hot, module.gke_cold]
}
