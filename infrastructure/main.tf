locals {
  regions = {
    europe  = "eu-west-1"
    america = "us-east-1"
    asia    = "ap-southeast-1"
  }
}


# -------------------------------------------------------------------
# Admin host module (Europe-only)
# -------------------------------------------------------------------
module "admin" {
  source              = "./modules/admin"
  providers           = { aws = aws.europe }
  resource_group_name = var.resource_group_name
  ssh_public_key_path = var.ssh_public_key_path
  admin_username      = var.admin_username
  tags                = var.tags

  vpc_id    = module.network_europe.vpc_id
  subnet_id = module.network_europe.subnet_ids[0]
}


# -------------------------------------------------------------------
# STEP 1: network in each region
# -------------------------------------------------------------------
module "network_europe" {
  source              = "./modules/network"
  providers           = { aws = aws.europe }
  resource_group_name = var.resource_group_name
  admin_sg_id         = module.admin.admin_sg_id
}
module "network_america" {
  source              = "./modules/network"
  providers           = { aws = aws.america }
  resource_group_name = var.resource_group_name
  admin_sg_id         = module.admin.admin_sg_id
}

module "network_asia" {
  source              = "./modules/network"
  providers           = { aws = aws.asia }
  resource_group_name = var.resource_group_name
  admin_sg_id         = module.admin.admin_sg_id
}

# -------------------------------------------------------------------
# STEP 2: ECS in each region, using network outputs
# -------------------------------------------------------------------
module "ecs_europe" {
  source                  = "./modules/ecs"
  providers               = { aws = aws.europe }
  resource_group_name     = var.resource_group_name
  cpu                     = var.cpu
  memory                  = var.memory
  min_replicas            = var.min_replicas
  max_replicas            = var.max_replicas
  request_count_threshold = var.request_count_threshold

  vpc_id      = module.network_europe.vpc_id
  subnet_ids  = module.network_europe.subnet_ids
  alb_sg_id   = module.network_europe.alb_sg_id
  region_name = "eu-west-1"
  instance_sg_id       =  module.network_europe.ecs_instance_sg_id
  admin_key_name       =  module.admin.admin_key_name
}

module "ecs_america" {
  source                  = "./modules/ecs"
  providers               = { aws = aws.america }
  resource_group_name     = var.resource_group_name
  cpu                     = var.cpu
  memory                  = var.memory
  min_replicas            = var.min_replicas
  max_replicas            = var.max_replicas
  request_count_threshold = var.request_count_threshold

  vpc_id      = module.network_america.vpc_id
  subnet_ids  = module.network_america.subnet_ids
  alb_sg_id   = module.network_america.alb_sg_id
  region_name = "us-east-1"
  instance_sg_id       =  module.network_america.ecs_instance_sg_id
  admin_key_name       =  module.admin.admin_key_name
}

module "ecs_asia" {
  source                  = "./modules/ecs"
  providers               = { aws = aws.asia }
  resource_group_name     = var.resource_group_name
  cpu                     = var.cpu
  memory                  = var.memory
  min_replicas            = var.min_replicas
  max_replicas            = var.max_replicas
  request_count_threshold = var.request_count_threshold

  vpc_id      = module.network_asia.vpc_id
  subnet_ids  = module.network_asia.subnet_ids
  alb_sg_id   = module.network_asia.alb_sg_id
  region_name = "ap-southeast-1"
  instance_sg_id       =  module.network_asia.ecs_instance_sg_id
  admin_key_name       =  module.admin.admin_key_name
}


# -------------------------------------------------------------------
# Traffic (Route53) module
# -------------------------------------------------------------------
module "traffic" {
  source              = "./modules/traffic"
  resource_group_name = var.resource_group_name

  alb_endpoints = {
    europe  = module.ecs_europe.alb_dns_name
    america = module.ecs_america.alb_dns_name
    asia    = module.ecs_asia.alb_dns_name
  }

}

