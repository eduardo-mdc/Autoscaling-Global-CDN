# terraform/modules/admin/outputs.tf - Admin Module Outputs

# Admin VM outputs
output "admin_public_ip" {
  description = "Public IP of the admin VM for SSH access"
  value       = google_compute_address.admin_ip.address
}

output "admin_private_ip" {
  description = "Private IP of the admin VM"
  value       = google_compute_instance.admin.network_interface[0].network_ip
}

output "admin_vpc_id" {
  description = "ID of the admin VPC network"
  value       = google_compute_network.admin_vpc.id
}

output "admin_vpc_self_link" {
  description = "Self link of the admin VPC network"
  value       = google_compute_network.admin_vpc.self_link
}

output "admin_subnet_cidr" {
  description = "CIDR range of the admin subnet"
  value       = google_compute_subnetwork.admin_subnet.ip_cidr_range
}

# Admin webapp outputs
output "admin_webapp_ip" {
  description = "Global IP address of the admin webapp"
  value       = google_compute_global_address.admin_webapp_ip.address
}

output "admin_webapp_urls" {
  description = "URLs to access the admin webapp"
  value = {
    ip_url    = "http://${google_compute_global_address.admin_webapp_ip.address}"
    domain_url = var.domain_name != "" ? "https://admin.${var.domain_name}" : "Domain not configured"
  }
}

output "admin_ssh_command" {
  description = "SSH command to connect to admin VM"
  value       = "ssh ${var.admin_username}@${google_compute_address.admin_ip.address}"
}

# DNS configuration
output "admin_dns_required" {
  description = "DNS configuration required for admin webapp"
  value = var.domain_name != "" ? {
    domain      = "admin.${var.domain_name}"
    record_type = "A"
    ip_address  = google_compute_global_address.admin_webapp_ip.address
    ttl         = 300
  } : null
}

# Backend service information (for debugging)
output "admin_backend_service" {
  description = "Admin webapp backend service details"
  value = {
    name        = google_compute_backend_service.admin_webapp.name
    self_link   = google_compute_backend_service.admin_webapp.self_link
    health_check = google_compute_health_check.admin_webapp.name
  }
}

# Summary for deployment scripts
output "admin_summary" {
  description = "Summary of admin infrastructure"
  value = {
    vm = {
      name       = google_compute_instance.admin.name
      public_ip  = google_compute_address.admin_ip.address
      private_ip = google_compute_instance.admin.network_interface[0].network_ip
      zone       = var.zone
      ssh_command = "ssh ${var.admin_username}@${google_compute_address.admin_ip.address}"
    }
    webapp = {
      global_ip    = google_compute_global_address.admin_webapp_ip.address
      ip_url       = "http://${google_compute_global_address.admin_webapp_ip.address}"
      domain_url   = var.domain_name != "" ? "https://admin.${var.domain_name}" : "Not configured"
      ssl_enabled  = var.domain_name != "" ? true : false
    }
    network = {
      vpc_name     = google_compute_network.admin_vpc.name
      subnet_cidr  = google_compute_subnetwork.admin_subnet.ip_cidr_range
    }
  }
}