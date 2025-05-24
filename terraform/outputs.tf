output "ssh_key_debug" {
  description = "Debug output to verify SSH key content"
  value       = "${substr(file(var.ssh_public_key_path), 0, 50)}..."
  sensitive   = true
}

output "admin_public_ip" {
  description = "Public IP of the admin VM"
  value       = module.admin.admin_public_ip
}

output "admin_ssh_command" {
  description = "SSH command to connect to admin VM"
  value       = "ssh ${var.admin_username}@${module.admin.admin_public_ip}"
}

output "gke_clusters" {
  description = "Map of GKE cluster details by region"
  value = {
    for region in var.regions :
    region => {
      cluster_name = module.gke[region].cluster_name
      endpoint     = module.gke[region].cluster_endpoint
    }
  }
}

output "gke_connect_commands" {
  description = "Commands to connect to each GKE cluster from admin VM"
  value = {
    for region in var.regions :
    region => "gcloud container clusters get-credentials ${module.gke[region].cluster_name} --region ${region} --project ${var.project_id}"
  }
}

output "load_balancer_ip" {
  description = "Global IP address of the load balancer"
  value       = module.loadbalancer.load_balancer_ip
}

output "network_details" {
  description = "VPC network details by region"
  value = {
    for region in var.regions :
    region => {
      network_name = module.network[region].network_name
      subnet_cidr  = module.network[region].subnet_cidr
    }
  }
}

output "waf_security_policy_id" {
  description = "ID of the created Cloud Armor security policy"
  value       = module.waf.security_policy_id
}

output "waf_security_policy_name" {
  description = "Name of the created Cloud Armor security policy"
  value       = module.waf.security_policy_name
}

output "ids_endpoints" {
  description = "Map of region to Cloud IDS endpoint details"
  value       = module.ids.ids_endpoints
}

# output "monitoring_dashboard_url" {
#   description = "URL to access the created monitoring dashboard"
#   value       = module.monitoring.dashboard_url
# }

output "dns_name_servers" {
  description = "The list of nameservers that should be configured with the domain registrar"
  value       = var.domain_name != "" ? module.dns[0].name_servers : []
}

output "admin_vm_ip" {
  description = "IP address of the admin VM"
  value       = module.admin.admin_public_ip
}

output "gke_cluster_endpoints" {
  description = "Map of region to GKE cluster endpoint"
  value = {
    for region, gke in module.gke : region => gke.cluster_endpoint
  }
}

