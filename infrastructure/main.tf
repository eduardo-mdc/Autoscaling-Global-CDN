# ------------------------------------------------------------------------------
# Root module for multi-region serverless application on Scaleway
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Network Module for each region
# ------------------------------------------------------------------------------
# Updated root main.tf
module "network_par" {
  source       = "./modules/network"
  project_name = var.project_name
  project_id   = var.project_id
  region       = "fr-par"
  zone         = "fr-par-1"
  ipv4_subnet  = "192.168.0.0/24"

  providers = {
    scaleway = scaleway.par
  }
}

module "network_ams" {
  source       = "./modules/network"
  project_name = var.project_name
  project_id   = var.project_id
  region       = "nl-ams"
  zone         = "nl-ams-1"
  ipv4_subnet  = "192.168.1.0/24"

  providers = {
    scaleway = scaleway.ams
  }
}

module "network_waw" {
  source       = "./modules/network"
  project_name = var.project_name
  project_id   = var.project_id
  region       = "pl-waw"
  zone         = "pl-waw-1"
  ipv4_subnet  = "192.168.2.0/24"

  providers = {
    scaleway = scaleway.waw
  }
}


# ------------------------------------------------------------------------------
# Kubernetes Clusters for each region
# ------------------------------------------------------------------------------

module "k8s_par" {
  source        = "./modules/k8s_cluster"
  project_id    = var.project_id
  project_name  = var.project_name
  vpc_id        = module.network_par.private_network_id
  vpc_cidr      = "192.168.0.0/24"  # Match with the subnet
  region        = "fr-par"
  k8s_version   = var.k8s_version

  # Initially blank, can be updated in a second apply after admin server is created
  admin_server_ip = ""

  providers = {
    scaleway = scaleway.par
  }
}

module "k8s_ams" {
  source        = "./modules/k8s_cluster"
  project_id    = var.project_id
  project_name  = var.project_name
  vpc_id        = module.network_ams.private_network_id
  vpc_cidr      = "192.168.1.0/24"  # Match with the subnet
  region        = "nl-ams"
  k8s_version   = var.k8s_version

  # Initially blank, can be updated in a second apply after admin server is created
  admin_server_ip = ""

  providers = {
    scaleway = scaleway.ams
  }
}

module "k8s_waw" {
  source        = "./modules/k8s_cluster"
  project_id    = var.project_id
  project_name  = var.project_name
  vpc_id        = module.network_waw.private_network_id
  vpc_cidr      = "192.168.2.0/24"  # Match with the subnet
  region        = "pl-waw"
  k8s_version   = var.k8s_version

  # Initially blank, can be updated in a second apply after admin server is created
  admin_server_ip = ""

  providers = {
    scaleway = scaleway.waw
  }
}

# ------------------------------------------------------------------------------
# Admin Server Module in Paris
# ------------------------------------------------------------------------------
module "admin_server" {
  source = "./modules/admin"

  project_name = var.project_name
  admin_username = var.admin_username
  ssh_public_key = var.ssh_public_key
  ssh_private_key_path = var.ssh_private_key_path

  # Connect to the Paris private network
  private_network_id = module.network_par.private_network_id

  # Get kubeconfigs from each cluster
  kubeconfig_paris = module.k8s_par.kubeconfig
  kubeconfig_amsterdam = module.k8s_ams.kubeconfig
  kubeconfig_warsaw = module.k8s_waw.kubeconfig

  providers = {
    scaleway = scaleway.par
  }

  depends_on = [
    module.k8s_par,
    module.k8s_ams,
    module.k8s_waw
  ]
}
