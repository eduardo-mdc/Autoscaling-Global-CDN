// Random suffix for DNS names
resource "random_string" "dns_suffix" {
  length  = 6
  special = false
  upper   = false
}

// Traffic Manager for global routing
resource "azurerm_traffic_manager_profile" "global_traffic_manager" {
  name                   = "global-cdn-tm"
  resource_group_name    = azurerm_resource_group.cdn_rg.name
  traffic_routing_method = "Geographic"

  dns_config {
    relative_name = "globalcdn-${random_string.dns_suffix.result}"
    ttl           = 60
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }

  tags = var.tags
}


resource "azurerm_traffic_manager_external_endpoint" "america_endpoint" {
  name       = "america-endpoint"
  profile_id = azurerm_traffic_manager_profile.global_traffic_manager.id
  target     = azurerm_container_app.america_app.ingress[0].fqdn
  weight     = 100
  enabled    = true

  geo_mappings = ["GEO-NA", "GEO-SA", "GEO-AS"] // North America, South America, Central America
}

resource "azurerm_traffic_manager_external_endpoint" "asia_endpoint" {
  name       = "asia-endpoint"
  profile_id = azurerm_traffic_manager_profile.global_traffic_manager.id
  target     = azurerm_container_app.asia_app.ingress[0].fqdn
  weight     = 100
  enabled    = true

  geo_mappings = ["GEO-AP"] // Asia Pacific
}

// Traffic Manager endpoints
resource "azurerm_traffic_manager_external_endpoint" "europe_endpoint" {
  name       = "europe-endpoint"
  profile_id = azurerm_traffic_manager_profile.global_traffic_manager.id
  target     = azurerm_container_app.europe_app.ingress[0].fqdn
  weight     = 100
  enabled    = true

  geo_mappings = ["GEO-EU", "GEO-ME", "GEO-AF", "WORLD"] // Europe, Middle East, and Africa and Default (WORLD)
}
