output "vpc_id" {
  description = "ID of the created VPC"
  value       = scaleway_vpc.main.id
}

output "private_network_id" {
  description = "ID of the private network"
  value       = scaleway_vpc_private_network.main.id
}

output "security_group_id" {
  description = "ID of the web security group"
  value       = scaleway_instance_security_group.web.id
}