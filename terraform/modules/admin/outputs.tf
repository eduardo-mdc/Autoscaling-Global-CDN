output "admin_public_ip" {
  description = "Public IP of the admin VM"
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