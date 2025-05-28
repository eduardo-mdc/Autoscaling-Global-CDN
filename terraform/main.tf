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
# Local values for consistent naming and CIDR calculations
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

  # Fixed admin CIDR to avoid circular dependency
  admin_cidr = "10.250.0.0/24"
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
# PHASE 3: KUBERNETES (Depends on networking)
# ============================================================================

# 3.1 GKE Clusters (depends on networks)
module "gke" {
  source   = "./modules/gke"
  for_each = local.region_numbers

  project_id        = var.project_id
  project_name      = var.project_name
  region            = each.key
  region_number     = each.value
  network_self_link = module.network[each.key].network_self_link
  subnet_self_link  = module.network[each.key].subnet_self_link
  admin_cidr        = local.admin_cidr  # Use local value

  # Node configuration
  min_nodes         = var.min_nodes
  max_nodes         = var.max_nodes
  node_machine_type = var.node_machine_type
  node_disk_size_gb = var.node_disk_size_gb
  node_disk_type    = var.node_disk_type
}

# 3.2 Bastion hosts (depends on networks)
module "bastion" {
  source   = "./modules/bastion"
  for_each = local.region_numbers

  project_id     = var.project_id
  project_name   = var.project_name
  region         = each.key
  machine_type   = "e2-medium"
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