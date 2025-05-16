output "admin_public_ip" {
  description = "Public IP of the admin EC2 instance"
  value       = aws_eip.admin_ip.public_ip
}

output "admin_instance_id" {
  description = "ID of the admin EC2 instance"
  value       = aws_instance.admin.id
}

output "admin_key_name" {
  description = "Name of the SSH keypair created for the admin host"
  value       = aws_key_pair.admin_key.key_name
}

output "admin_sg_id" {
  description = "Security Group ID for the bastion/admin host"
  value       = aws_security_group.admin_sg.id
}