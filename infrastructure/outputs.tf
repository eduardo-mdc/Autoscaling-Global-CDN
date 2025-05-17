output "admin_public_ip" {
  description = "Public IP of the admin droplet"
  value       = module.admin.admin_public_ip
}

# Kubernetes cluster outputs
output "kubernetes_clusters" {
  description = "Map of Kubernetes cluster details by region"
  value = {
    for region in var.regions :
    region => {
      cluster_id   = module.kubernetes[region].cluster_id
      cluster_name = module.kubernetes[region].cluster_name
      endpoint     = module.kubernetes[region].kubernetes_endpoint
    }
  }
}

# Load balancer endpoints
output "loadbalancer_ips" {
  description = "Map of load balancer IPs by region"
  value = {
    for region in var.regions :
    region => module.kubernetes[region].loadbalancer_ip
  }
}

# Domain outputs (if domain is configured)
output "domain_endpoints" {
  description = "Domain endpoints for each region"
  value       = module.traffic.regional_domains
}