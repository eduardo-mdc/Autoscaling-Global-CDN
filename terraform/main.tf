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

module "loadbalancer" {
  source = "./modules/loadbalancer"

  project_id   = var.project_id
  project_name = var.project_name
  regions      = var.regions
  domain_name  = var.domain_name

  # Domain features
  enable_regional_subdomains = var.enable_regional_subdomains
  enable_caa_records        = var.enable_caa_records
  additional_domains        = var.additional_domains

  backend_services = []
  regional_backend_services = {}

  depends_on = [module.gke]
}

# Create WAF security policy with Cloud Armor
module "waf" {
  source = "./modules/waf"
  project_id   = var.project_id
  project_name = var.project_name
  name         = "${var.project_name}-security-policy"
  description  = "WAF security policy to protect against common web attacks"
  
  # Default configurations
  default_rule_action = "allow"
  blocked_ips         = []
  
  # Enable protection features
  enable_xss_protection            = true
  enable_sqli_protection           = true
  enable_rce_protection            = true
  enable_lfi_protection            = true
  enable_protocol_attack_protection = true
  enable_scanner_protection        = true
  
  # Rate limiting
  enable_rate_limiting   = true
  rate_limit_threshold   = 100
  
  # Geo restrictions (disabled by default)
  enable_geo_restriction  = false
  geo_restriction_regions = []
}

# Create Cloud IDS for each region
module "ids" {
  source = "./modules/ids"
  project_id   = var.project_id
  project_name = var.project_name
  regions      = var.regions
  zones        = var.zones
  severity     = "INFORMATIONAL"
  
  # Network configuration for each region
  network_self_links = {
    for region, network in module.network : region => network.network_self_link
  }
  
  subnet_self_links = {
    for region, network in module.network : region => network.subnet_self_link
  }
  
  # IDS configuration
  ids_instance_name_prefix = "${var.project_name}-ids"
  enable_packet_mirroring  = true
  
  # Optional packet mirroring configuration
  packet_mirroring_tags      = []
  packet_mirroring_cidr_ranges = []
}

# Create monitoring dashboards for load balancer
# module "monitoring" {
#   source = "./modules/monitoring"
#   project_id   = var.project_id
#   project_name = var.project_name
#   regions      = var.regions
#   zones        = var.zones
  
#   # Load balancer configuration
#   load_balancer_name    = "${var.project_name}-lb"
#   backend_service_names = []
  
#   # Dashboard configuration
#   dashboard_display_name = "${var.project_name} - Load Balancer Monitoring"
#   dashboard_refresh_rate = 300
  
#   # Enable monitoring features
#   enable_latency_monitoring      = true
#   enable_request_count_monitoring = true
#   enable_backend_health_monitoring = false
  
#   # Alert thresholds
#   latency_threshold_ms          = 1000
#   error_rate_threshold_percent  = 5
#   backend_health_threshold_percent = 80
# }

# Create DNS zone and records
module "dns" {
  source = "./modules/dns"
  project_id   = var.project_id
  project_name = var.project_name
  domain_name  = var.domain_name
  description  = "Managed DNS zone for ${var.project_name}"
  
  # Record configuration
  load_balancer_ip = module.loadbalancer.load_balancer_ip
  grafana_vm_ip    = module.admin.admin_public_ip
  
  # DNS configuration
  ttl           = 300
  enable_dnssec = true
  is_private_zone = false
  
  # Only create DNS resources if domain_name is provided
  count = var.domain_name != "" ? 1 : 0
}
