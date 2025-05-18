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