output "europe_alb_dns" {
  description = "ALB DNS name in eu-west-1"
  value       = module.ecs_europe.alb_dns_name
}

output "america_alb_dns" {
  description = "ALB DNS name in us-east-1"
  value       = module.ecs_america.alb_dns_name
}

output "asia_alb_dns" {
  description = "ALB DNS name in ap-southeast-1"
  value       = module.ecs_asia.alb_dns_name
}


# ECS cluster & service outputs
output "europe_cluster_id" {
  description = "ECS Cluster ID in eu-west-1"
  value       = module.ecs_europe.cluster_id
}

output "europe_service_arn" {
  description = "ECS Service ARN in eu-west-1"
  value       = module.ecs_europe.service_arn
}

# Repeat for the other regions…
output "america_cluster_id" {
  value = module.ecs_america.cluster_id
}
output "america_service_arn" {
  value = module.ecs_america.service_arn
}

output "asia_cluster_id" {
  value = module.ecs_asia.cluster_id
}
output "asia_service_arn" {
  value = module.ecs_asia.service_arn
}

output "admin_public_ip" {
  description = "Public IP of the Admin EC2 host"
  value       = module.admin.admin_public_ip
}

output "alb_endpoints" {
  description = "Map of ALB DNS names by region"
  value       = module.traffic.alb_endpoints
}