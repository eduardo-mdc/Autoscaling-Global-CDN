// 04_traffic.tf - Traffic Manager configuration for v4.28.0

// Traffic Manager for global routing
resource "azurerm_traffic_manager_profile" "global_traffic_manager" {
  name                = "global-cdn-tm"
  resource_group_name = azurerm_resource_group.cdn_rg.name

  traffic_routing_method = "Geographic"

  dns_config {
    relative_name = "globalrouting"
    ttl           = 60
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/health"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }

  tags = var.tags
}

// Europe endpoint in Traffic Manager
resource "azurerm_traffic_manager_external_endpoint" "europe_endpoint" {
  name              = "europe-endpoint"
  profile_id        = azurerm_traffic_manager_profile.global_traffic_manager.id
  target            = azurerm_container_app.europe_cdn_app.ingress[0].fqdn
  weight            = 100
  enabled           = true
  geo_mappings      = ["GEO-EU", "GEO-ME"]  // Europe and Middle East
}

// America endpoint in Traffic Manager
resource "azurerm_traffic_manager_external_endpoint" "america_endpoint" {
  name              = "america-endpoint"
  profile_id        = azurerm_traffic_manager_profile.global_traffic_manager.id
  target            = azurerm_container_app.america_cdn_app.ingress[0].fqdn
  weight            = 100
  enabled           = true
  geo_mappings      = ["GEO-NA", "GEO-SA"]  // North and South America
}

// Asia endpoint in Traffic Manager
resource "azurerm_traffic_manager_external_endpoint" "asia_endpoint" {
  name              = "asia-endpoint"
  profile_id        = azurerm_traffic_manager_profile.global_traffic_manager.id
  target            = azurerm_container_app.asia_cdn_app.ingress[0].fqdn
  weight            = 100
  enabled           = true
  geo_mappings      = ["GEO-AP", "GEO-AS"]  // Asia Pacific and Asia
}

// Global/Default endpoint (using Europe as default)
resource "azurerm_traffic_manager_external_endpoint" "default_endpoint" {
  name              = "default-endpoint"
  profile_id        = azurerm_traffic_manager_profile.global_traffic_manager.id
  target            = azurerm_container_app.europe_cdn_app.ingress[0].fqdn
  weight            = 100
  enabled           = true
  geo_mappings      = ["WORLD"]  // Default for regions not covered above
}