# Serverless Container Module for Scaleway

# Create a container namespace
resource "scaleway_container_namespace" "main" {
  name        = "${var.project_name}-ns-${var.region}"
  description = "Container namespace for ${var.project_name} in ${var.region}"
  region      = var.region
}

# Create a container
resource "scaleway_container" "app" {
  name            = "${var.project_name}-container-${var.region}"
  namespace_id    = scaleway_container_namespace.main.id
  registry_image  = var.container_image
  port            = var.container_port
  cpu_limit       = 140    # 140mCPU, enough for basic workloads
  memory_limit    = var.memory_limit
  min_scale       = var.min_scale
  max_scale       = var.max_scale
  timeout         = 300    # Default timeout of 5 minutes
  max_concurrency = 50     # Reasonable default for concurrent requests
  privacy         = "public"

  # Connect to the private network for isolation
  # Note: As of May 2025, Scaleway Containers don't directly connect to private networks
  # This would need to be configured through container environment variables or settings

  environment_variables = {
    "REGION" = var.region
  }

  # Deploy with a redirection to the container's URL
  deploy = true
}
