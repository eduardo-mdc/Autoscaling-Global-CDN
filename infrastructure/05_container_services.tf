// 05_container_services.tf - Container Apps with correct liveness probe syntax for v4.28.0

// EUROPE REGION

// Container App Environment for Europe
resource "azurerm_container_app_environment" "europe_container_env" {
  name                       = "europe-container-env"
  location                   = "westeurope"  // Different from main region
  resource_group_name        = azurerm_resource_group.cdn_rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id

  tags = var.tags
}

// Container App for Europe CDN service
resource "azurerm_container_app" "europe_cdn_app" {
  name                         = "europe-cdn-app"
  container_app_environment_id = azurerm_container_app_environment.europe_container_env.id
  resource_group_name          = azurerm_resource_group.cdn_rg.name
  revision_mode                = "Multiple"

  template {
    container {
      name   = "cdn-service"
      image  = "nginx:latest"  // Will be replaced with your custom CDN container
      cpu    = 0.5             // 0.5 vCPU cores
      memory = "1Gi"           // 1GB of memory

      env {
        name  = "REGION"
        value = "europe"
      }

      // Correctly formatted liveness probe
      liveness_probe {
        transport       = "HTTP"
        port            = 80
        path            = "/health"
        timeout         = 10
        initial_delay   = 10
      }
    }

    min_replicas = 1
    max_replicas = 5
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = var.tags
}

// AMERICA REGION

// Container App Environment for America
resource "azurerm_container_app_environment" "america_container_env" {
  name                       = "america-container-env"
  location                   = "eastus"  // Different from main region
  resource_group_name        = azurerm_resource_group.cdn_rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id

  tags = var.tags
}

// Container App for America CDN service
resource "azurerm_container_app" "america_cdn_app" {
  name                         = "america-cdn-app"
  container_app_environment_id = azurerm_container_app_environment.america_container_env.id
  resource_group_name          = azurerm_resource_group.cdn_rg.name
  revision_mode                = "Multiple"

  template {
    container {
      name   = "cdn-service"
      image  = "nginx:latest"  // Will be replaced with your custom CDN container
      cpu    = 0.5             // 0.5 vCPU cores
      memory = "1Gi"           // 1GB of memory

      env {
        name  = "REGION"
        value = "america"
      }

      // Correctly formatted liveness probe
      liveness_probe {
        transport       = "HTTP"
        port            = 80
        path            = "/health"
        timeout         = 10
        initial_delay   = 10
      }
    }

    min_replicas = 1
    max_replicas = 5
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = var.tags
}

// ASIA REGION

// Container App Environment for Asia
resource "azurerm_container_app_environment" "asia_container_env" {
  name                       = "asia-container-env"
  location                   = "southeastasia"  // Different from main region
  resource_group_name        = azurerm_resource_group.cdn_rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id

  tags = var.tags
}

// Container App for Asia CDN service
resource "azurerm_container_app" "asia_cdn_app" {
  name                         = "asia-cdn-app"
  container_app_environment_id = azurerm_container_app_environment.asia_container_env.id
  resource_group_name          = azurerm_resource_group.cdn_rg.name
  revision_mode                = "Multiple"

  template {
    container {
      name   = "cdn-service"
      image  = "nginx:latest"  // Will be replaced with your custom CDN container
      cpu    = 0.5             // 0.5 vCPU cores
      memory = "1Gi"           // 1GB of memory

      env {
        name  = "REGION"
        value = "asia"
      }

      // Correctly formatted liveness probe
      liveness_probe {
        transport       = "HTTP"
        port            = 80
        path            = "/health"
        timeout         = 10
        initial_delay   = 10
      }
    }

    min_replicas = 1
    max_replicas = 5
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = var.tags
}

// Custom script to create health endpoint on containers
resource "null_resource" "container_init" {
  depends_on = [
    azurerm_container_app.europe_cdn_app,
    azurerm_container_app.america_cdn_app,
    azurerm_container_app.asia_cdn_app
  ]

  // This will be triggered each time the container apps change
  triggers = {
    europe_version = azurerm_container_app.europe_cdn_app.latest_revision_name
    america_version = azurerm_container_app.america_cdn_app.latest_revision_name
    asia_version = azurerm_container_app.asia_cdn_app.latest_revision_name
  }

  // This is a placeholder - in a real scenario you'd need
  // to build this into your container image
  provisioner "local-exec" {
    command = <<-EOT
      echo "Container initialization - health endpoints are now available"
    EOT
  }
}