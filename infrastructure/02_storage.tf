// 02_storage.tf - Simplified storage with master disk

// Storage account for master content
resource "azurerm_storage_account" "cdn_storage" {
  name                     = "cdnmainstorage"  // Must be globally unique
  resource_group_name      = azurerm_resource_group.cdn_rg.name
  location                 = azurerm_resource_group.cdn_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  // No network rules - accessible from anywhere

  tags = var.tags
}

// Container for blob storage
resource "azurerm_storage_container" "cdn_assets" {
  name                  = "assets"
  storage_account_name  = azurerm_storage_account.cdn_storage.name
  container_access_type = "blob"  // Public access for CDN resources
}

// Master disk for admin VM
resource "azurerm_managed_disk" "master_disk" {
  name                 = "master-disk"
  location             = azurerm_resource_group.cdn_rg.location
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  storage_account_type = var.master_disk_storage_account_type
  create_option        = "Empty"
  disk_size_gb         = var.master_disk_size_gb

  tags = var.tags
}