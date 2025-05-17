output "vpc_ids" {
  description = "VPC IDs by region"
  value = {
    "fr-par" = module.network_par.vpc_id
    "nl-ams" = module.network_ams.vpc_id
    "pl-waw" = module.network_waw.vpc_id
  }
}

output "k8s_cluster_ids" {
  description = "Kubernetes cluster IDs by region"
  value = {
    "fr-par" = module.k8s_par.cluster_id
    "nl-ams" = module.k8s_ams.cluster_id
    "pl-waw" = module.k8s_waw.cluster_id
  }
}

output "k8s_cluster_endpoints" {
  description = "Kubernetes cluster API endpoints by region"
  value = {
    "fr-par" = module.k8s_par.cluster_endpoint
    "nl-ams" = module.k8s_ams.cluster_endpoint
    "pl-waw" = module.k8s_waw.cluster_endpoint
  }
}

output "k8s_security_group_ids" {
  description = "Security group IDs for Kubernetes clusters by region"
  value = {
    "fr-par" = module.k8s_par.security_group_id
    "nl-ams" = module.k8s_ams.security_group_id
    "pl-waw" = module.k8s_waw.security_group_id
  }
}

output "admin_server_public_ip" {
  description = "Public IP address of the admin server"
  value       = module.admin_server.admin_server_public_ip
}

output "admin_server_private_ip" {
  description = "Private IP address of the admin server"
  value       = module.admin_server.admin_server_private_ip
}

output "gateways" {
  description = "VPC gateway IDs by region"
  value = {
    "fr-par" = module.network_ams.gateway_id,
    "nl-ams" = module.network_waw.gateway_id,
    "pl-waw" = module.network_par.gateway_id
  }
}

output "private_network_ids" {
  description = "Private network IDs by region"
  value = {
    "fr-par" = module.network_par.private_network_id
    "nl-ams" = module.network_ams.private_network_id
    "pl-waw" = module.network_waw.private_network_id
  }
}