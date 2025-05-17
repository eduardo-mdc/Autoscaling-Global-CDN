output "admin_server_id" {
  description = "ID of the admin server"
  value       = scaleway_instance_server.admin.id
}

output "admin_server_public_ip" {
  description = "Public IP of the admin server"
  value       = scaleway_instance_server.admin.public_ip
}

output "admin_server_private_ip" {
  description = "Private IP of the admin server"
  value       = scaleway_instance_server.admin.private_ip
}

output "admin_security_group_id" {
  description = "ID of the admin security group"
  value       = scaleway_instance_security_group.admin.id
}