output "vpc_id" {
  description = "ID of the VPC"
  value       = scaleway_vpc.this.id
}

output "private_network_id" {
  description = "ID of the private network"
  value       = scaleway_vpc_private_network.this.id
}

output "gateway_id" {
  description = "ID of the public gateway (if enabled)"
  value       = var.gw_enabled ? scaleway_vpc_public_gateway.this[0].id : null
}


output "gateway_network_id" {
  description = "ID of the gateway network (if enabled)"
  value       = var.gw_enabled ? scaleway_vpc_gateway_network.this[0].id : null
}