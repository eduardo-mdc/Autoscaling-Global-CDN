// Resource group for the entire infrastructure
resource "azurerm_resource_group" "cdn_rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

// Log Analytics workspace for monitoring
resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "cdn-log-analytics"
  location            = azurerm_resource_group.cdn_rg.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

// Container Apps Environments - One for each region
resource "azurerm_container_app_environment" "europe" {
  name                       = "europe-container-env"
  location                   = var.regions.europe.location
  resource_group_name        = azurerm_resource_group.cdn_rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id
  infrastructure_subnet_id   = azurerm_subnet.europe_container_apps_subnet.id
  tags                       = var.tags
}

resource "azurerm_container_app_environment" "america" {
  name                       = "america-container-env"
  location                   = var.regions.america.location
  resource_group_name        = azurerm_resource_group.cdn_rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id
  infrastructure_subnet_id   = azurerm_subnet.america_container_apps_subnet.id
  tags                       = var.tags
}

resource "azurerm_container_app_environment" "asia" {
  name                       = "asia-container-env"
  location                   = var.regions.asia.location
  resource_group_name        = azurerm_resource_group.cdn_rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id
  infrastructure_subnet_id   = azurerm_subnet.asia_container_apps_subnet.id
  tags                       = var.tags
}

// Container Apps - One for each region using public DockerHub nginx image
resource "azurerm_container_app" "europe_app" {
  name                         = "europe-cdn-app"
  container_app_environment_id = azurerm_container_app_environment.europe.id
  resource_group_name          = azurerm_resource_group.cdn_rg.name
  revision_mode                = "Multiple"

  // Required secret for http_scale_rule authentication
  secret {
    name  = "dummy-secret"
    value = "dummy-value"
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "europe-cdn-container"
      image  = "nginx:latest"
      cpu    = var.cpu
      memory = var.memory

      env {
        name  = "REGION"
        value = "Europe"
      }

      liveness_probe {
        transport       = "HTTP"
        port            = 80
        path            = "/"
        interval_seconds = 30
        timeout         = 1
        failure_count_threshold = 3
      }
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    http_scale_rule {
      name                = "http-scale-rule"
      concurrent_requests = 10
      authentication {
        secret_name       = "dummy-secret"
        trigger_parameter = "triggerName"
      }
    }
  }

  tags = var.tags
}

resource "azurerm_container_app" "america_app" {
  name                         = "america-cdn-app"
  container_app_environment_id = azurerm_container_app_environment.america.id
  resource_group_name          = azurerm_resource_group.cdn_rg.name
  revision_mode                = "Multiple"

  // Required secret for http_scale_rule authentication
  secret {
    name  = "dummy-secret"
    value = "dummy-value"
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "america-cdn-container"
      image  = "nginx:latest"
      cpu    = var.cpu
      memory = var.memory

      env {
        name  = "REGION"
        value = "America"
      }

      liveness_probe {
        transport       = "HTTP"
        port            = 80
        path            = "/"
        interval_seconds = 30
        timeout         = 1
        failure_count_threshold = 3
      }
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    http_scale_rule {
      name                = "http-scale-rule"
      concurrent_requests = 10
      authentication {
        secret_name       = "dummy-secret"
        trigger_parameter = "triggerName"
      }
    }
  }

  tags = var.tags
}

resource "azurerm_container_app" "asia_app" {
  name                         = "asia-cdn-app"
  container_app_environment_id = azurerm_container_app_environment.asia.id
  resource_group_name          = azurerm_resource_group.cdn_rg.name
  revision_mode                = "Multiple"

  // Required secret for http_scale_rule authentication
  secret {
    name  = "dummy-secret"
    value = "dummy-value"
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    container {
      name   = "asia-cdn-container"
      image  = "nginx:latest"
      cpu    = var.cpu
      memory = var.memory

      env {
        name  = "REGION"
        value = "Asia"
      }

      liveness_probe {
        transport       = "HTTP"
        port            = 80
        path            = "/"
        interval_seconds = 30
        timeout         = 1
        failure_count_threshold = 3
      }
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    http_scale_rule {
      name                = "http-scale-rule"
      concurrent_requests = 10
      authentication {
        secret_name       = "dummy-secret"
        trigger_parameter = "triggerName"
      }
    }
  }

  tags = var.tags
}