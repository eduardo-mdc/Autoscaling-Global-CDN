# modules/bastion/outputs.tf

output "bastion_internal_ip" {
  description = "Internal IP address of the bastion host"
  value       = google_compute_instance.bastion.network_interface[0].network_ip
}

output "bastion_name" {
  description = "Name of the bastion instance"
  value       = google_compute_instance.bastion.name
}

output "bastion_zone" {
  description = "Zone where bastion is deployed"
  value       = google_compute_instance.bastion.zone
}

output "bastion_ssh_command_via_admin" {
  description = "SSH command to connect to bastion via admin VM"
  value       = "ssh -J ${var.admin_username}@<admin-ip> ${var.admin_username}@${google_compute_instance.bastion.network_interface[0].network_ip}"
}