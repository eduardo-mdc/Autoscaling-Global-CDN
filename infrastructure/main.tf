# Main Terraform configuration for global multi-region infrastructure
# Focus on infrastructure only - no Kubernetes resource application

# Configure Google provider
provider "google" {
  project     = var.project_id
  credentials = file(var.credentials_file)
  region      = var.regions[0]  # Default to first region
}

provider "google-beta" {
  project     = var.project_id
  credentials = file(var.credentials_file)
  region      = var.regions[0]  # Default to first region
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

# Create VPC networks in each region
module "network" {
  source   = "./modules/network"
  for_each = local.region_numbers

  project_id       = var.project_id
  project_name     = var.project_name
  region           = each.key
  region_number    = each.value
  admin_cidr       = module.admin.admin_subnet_cidr
  other_region_cidrs = local.other_region_cidrs[each.key]
}

# Create admin VM in the first region
module "admin" {
  source = "./modules/admin"

  project_id     = var.project_id
  project_name   = var.project_name
  region         = var.regions[0]
  zone           = var.zones[var.regions[0]]
  machine_type   = var.admin_machine_type
  admin_username = var.admin_username
  ssh_public_key = file(var.ssh_public_key_path)

  # Pass all VPC network links for peering
  vpc_network_links = [
    for region in var.regions :
    module.network[region].network_self_link
  ]

  # All regions for admin scripts
  all_regions = var.regions
}

# Create GKE clusters in each region
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
}

# Create global HTTP(S) load balancer
module "loadbalancer" {
  source = "./modules/loadbalancer"

  project_id    = var.project_id
  project_name  = var.project_name
  regions       = var.regions
  domain_name   = var.domain_name
  enable_cdn    = var.enable_cdn

  # These would typically be the GKE Ingress NEGs
  # In a real implementation, you'd extract these from GKE
  backend_services = []

  regional_backend_services = {}
}