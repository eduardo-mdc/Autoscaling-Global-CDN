# Main Terraform configuration for global multi-region infrastructure

# Configure Google provider
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

# Fetch region information for mapping
locals {
  # Map regions to numeric IDs for CIDR calculations
  region_numbers = {
    for idx, region in var.regions : region => idx + 1
  }

  # Build a map of CIDR ranges for each region
  region_cidrs = {
    for region in var.regions :
    region => "10.${local.region_numbers[region]}.0.0/20"
  }

  # For each region, create a list of other regions' CIDRs
  other_region_cidrs = {
    for region in var.regions :
    region => [
      for r, cidr in local.region_cidrs :
      cidr if r != region
    ]
  }
}

# Create admin VM FIRST (no dependencies)
module "admin" {
  source = "./modules/admin"

  project_id     = var.project_id
  project_name   = var.project_name
  region         = var.regions[0]
  zone           = var.zones[var.regions[0]]
  machine_type   = var.admin_machine_type
  admin_username = var.admin_username
  ssh_public_key = file(var.ssh_public_key_path)

  # Pass region numbers for dynamic master CIDR calculation
  region_numbers = local.region_numbers

  # All regions for admin scripts (no module dependencies)
  all_regions = var.regions
}

# Create VPC networks in each region (depends on admin)
module "network" {
  source   = "./modules/network"
  for_each = local.region_numbers

  project_id            = var.project_id
  project_name          = var.project_name
  region                = each.key
  region_number         = each.value
  admin_cidr            = module.admin.admin_subnet_cidr
  other_region_cidrs    = local.other_region_cidrs[each.key]
}

# Update admin module with network links (after networks are created)
# This creates the VPC peering connections FROM admin TO regional networks
resource "google_compute_network_peering" "admin_to_region" {
  for_each = local.region_numbers

  name         = "${var.project_name}-admin-to-region-${each.value}"
  network      = module.admin.admin_vpc_self_link
  peer_network = module.network[each.key].network_self_link

  # Enable route sharing
  export_custom_routes = true
  import_custom_routes = true

  # Enable subnet route sharing
  export_subnet_routes_with_public_ip = true
  import_subnet_routes_with_public_ip = true
}

resource "google_compute_network_peering" "region_to_admin" {
  for_each = local.region_numbers

  name         = "${var.project_name}-region-${each.value}-to-admin"
  network      = module.network[each.key].network_self_link
  peer_network = module.admin.admin_vpc_self_link

  export_custom_routes = true
  import_custom_routes = true
  export_subnet_routes_with_public_ip = true
  import_subnet_routes_with_public_ip = true
}

# Create GKE clusters in each region (depends on networks)
module "gke" {
  source   = "./modules/gke"
  for_each = local.region_numbers

  project_id        = var.project_id
  project_name      = var.project_name
  region            = each.key
  region_number     = each.value
  network_self_link = module.network[each.key].network_self_link
  subnet_self_link  = module.network[each.key].subnet_self_link
  admin_cidr        = module.admin.admin_subnet_cidr

  min_nodes         = var.min_nodes
  max_nodes         = var.max_nodes
  node_machine_type = var.node_machine_type
  node_disk_size_gb = var.node_disk_size_gb
  node_disk_type    = var.node_disk_type
}

module "bastion" {
  source   = "./modules/bastion"
  for_each = local.region_numbers

  project_id     = var.project_id
  project_name   = var.project_name
  region         = each.key
  machine_type   = "e2-medium"  # Small instance for bastion
  admin_username = var.admin_username
  ssh_public_key = file(var.ssh_public_key_path)

  # Network configuration
  network_name      = module.network[each.key].network_name
  subnet_self_link  = module.network[each.key].subnet_self_link
  admin_cidr        = module.admin.admin_subnet_cidr
}

# Create global HTTP(S) load balancer
module "loadbalancer" {
  source = "./modules/loadbalancer"

  project_id   = var.project_id
  project_name = var.project_name
  regions      = var.regions
  domain_name  = var.domain_name
  enable_cdn   = var.enable_cdn

  backend_services = []
  regional_backend_services = {}
}