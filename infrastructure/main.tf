# ------------------------------------------------------------------------------
# Root module for multi-region serverless application on Scaleway
# ------------------------------------------------------------------------------

terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.31.0"
    }
  }
  required_version = ">= 1.0.0"
}

# ------------------------------------------------------------------------------
# Network Module for each region
# ------------------------------------------------------------------------------
module "network_par" {
  source       = "./modules/network"
  project_name = var.project_name
  region       = "fr-par"

  providers = {
    scaleway = scaleway.par
  }
}

module "network_ams" {
  source       = "./modules/network"
  project_name = var.project_name
  region       = "nl-ams"

  providers = {
    scaleway = scaleway.ams
  }
}

module "network_waw" {
  source       = "./modules/network"
  project_name = var.project_name
  region       = "pl-waw"

  providers = {
    scaleway = scaleway.waw
  }
}


# ------------------------------------------------------------------------------
# Serverless Deployments for each region
# ------------------------------------------------------------------------------
module "serverless_par" {
  source       = "./modules/serverless"
  project_name = var.project_name
  region       = "fr-par"
  vpc_id       = module.network_par.vpc_id
  container_image = var.container_image
  container_port  = var.container_port
  min_scale       = var.min_scale
  max_scale       = var.max_scale
  memory_limit    = var.memory_limit

  providers = {
    scaleway = scaleway.par
  }
}

module "serverless_ams" {
  source       = "./modules/serverless"
  project_name = var.project_name
  region       = "nl-ams"
  vpc_id       = module.network_ams.vpc_id
  container_image = var.container_image
  container_port  = var.container_port
  min_scale       = var.min_scale
  max_scale       = var.max_scale
  memory_limit    = var.memory_limit

  providers = {
    scaleway = scaleway.ams
  }
}

module "serverless_waw" {
  source       = "./modules/serverless"
  project_name = var.project_name
  region       = "pl-waw"
  vpc_id       = module.network_waw.vpc_id
  container_image = var.container_image
  container_port  = var.container_port
  min_scale       = var.min_scale
  max_scale       = var.max_scale
  memory_limit    = var.memory_limit

  providers = {
    scaleway = scaleway.waw
  }
}

