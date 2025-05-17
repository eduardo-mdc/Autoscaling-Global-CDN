output "container_id" {
  description = "ID of the serverless container"
  value       = scaleway_container.app.id
}

output "endpoint_url" {
  description = "URL endpoint for the container"
  value       = scaleway_container.app.domain_name
}

output "namespace_id" {
  description = "ID of the container namespace"
  value       = scaleway_container_namespace.main.id
}

output "status" {
  description = "Deployment status of the container"
  value       = scaleway_container.app.status
}