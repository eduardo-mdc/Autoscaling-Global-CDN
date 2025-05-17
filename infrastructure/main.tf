# -------------------------------------------------------------------
# Create network in each region
# -------------------------------------------------------------------
module "network" {
  for_each = toset(var.regions)

  source       = "./modules/network"
  project_name = var.project_name
  region       = each.key

  providers = {
    digitalocean = digitalocean
  }
}

# -------------------------------------------------------------------
# Admin host module (Amsterdam region only, similar to Europe-only in original)
# -------------------------------------------------------------------
module "admin" {
  source              = "./modules/admin"
  project_name        = var.project_name
  region              = var.regions[0]  # First region (Amsterdam/Europe)
  vpc_id              = module.network[var.regions[0]].vpc_id
  ssh_public_key_path = var.ssh_public_key_path
  admin_username      = var.admin_username
  tags                = var.tags

  providers = {
    digitalocean = digitalocean
  }
}

# -------------------------------------------------------------------
# Kubernetes clusters in each region
# -------------------------------------------------------------------
module "kubernetes" {
  for_each = toset(var.regions)

  source               = "./modules/kubernetes"
  project_name         = var.project_name
  region               = each.key
  vpc_id               = module.network[each.key].vpc_id
  min_nodes            = var.min_nodes
  max_nodes            = var.max_nodes
  admin_ssh_fingerprint = module.admin.admin_key_fingerprint

  providers = {
    digitalocean = digitalocean
  }
}

# -------------------------------------------------------------------
# Traffic management with load balancers
# -------------------------------------------------------------------
module "traffic" {
  source = "./modules/traffic"

  project_name    = var.project_name
  domain_name     = "" # Set your domain name here if you have one
  regions         = var.regions
  loadbalancer_ips = {
    for region in var.regions :
    region => module.kubernetes[region].loadbalancer_ip
  }

  providers = {
    digitalocean = digitalocean
  }
}

# -------------------------------------------------------------------
# Just use the default project for simplicity
# -------------------------------------------------------------------
data "digitalocean_project" "default" {
  name = var.project_name
}

# Add resources to the project after they've been created
resource "digitalocean_project_resources" "project_resources" {
  project = data.digitalocean_project.default.id

  # Add resources using proper URN format
  resources = [
    "do:droplet:${module.admin.admin_droplet_id}"
  ]

  # Make sure the resources are created first
  depends_on = [
    module.admin,
    module.kubernetes,
    module.network
  ]
}