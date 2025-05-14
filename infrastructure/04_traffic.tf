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

// America endpoint in Traffic Manager
resource "azurerm_traffic_manager_external_endpoint" "america_endpoint" {
  name              = "america-endpoint"
  profile_id        = azurerm_traffic_manager_profile.global_traffic_manager.id
  target            = azurerm_public_ip.america_lb_ip.fqdn
  weight            = 100
  enabled           = true
  geo_mappings      = ["GEO-NA", "GEO-SA"]  // North and South America
}

// Asia endpoint in Traffic Manager
resource "azurerm_traffic_manager_external_endpoint" "asia_endpoint" {
  name              = "asia-endpoint"
  profile_id        = azurerm_traffic_manager_profile.global_traffic_manager.id
  target            = azurerm_public_ip.asia_lb_ip.fqdn
  weight            = 100
  enabled           = true
  geo_mappings      = ["GEO-AP", "GEO-AS"]  // Asia Pacific and Asia
}

// Europe endpoint in Traffic Manager
resource "azurerm_traffic_manager_external_endpoint" "europe_endpoint" {
  name              = "europe-endpoint"
  profile_id        = azurerm_traffic_manager_profile.global_traffic_manager.id
  target            = azurerm_public_ip.europe_lb_ip.fqdn
  weight            = 100
  enabled           = true
  geo_mappings      = ["GEO-EU", "GEO-ME", "WORLD"]  // Europe and Middle East and Default (World)
}

