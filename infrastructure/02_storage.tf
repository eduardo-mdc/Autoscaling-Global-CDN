// 02_storage.tf - Storage accounts and shares

// Storage account for master content
resource "azurerm_storage_account" "cdn_storage" {
  name                     = "cdnmainstorage"  // Must be globally unique
  resource_group_name      = azurerm_resource_group.cdn_rg.name
  location                 = azurerm_resource_group.cdn_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"  // Force minimum TLS version instead

  // Ensure storage account access is restricted to trusted networks
  network_rules {
    default_action = "Deny"
    ip_rules       = ["0.0.0.0/0"]  // Replace with your allowed IP ranges
    virtual_network_subnet_ids = [
      azurerm_subnet.admin_subnet.id
    ]
  }

  tags = var.tags
}

// File share for content distribution
resource "azurerm_storage_share" "cdn_share" {
  name                 = "cdnshare"
  storage_account_name = azurerm_storage_account.cdn_storage.name
  quota                = 100  // GB
}

// Container for blob storage (optional, for larger static assets)
resource "azurerm_storage_container" "cdn_assets" {
  name                  = "assets"
  storage_account_name  = azurerm_storage_account.cdn_storage.name
  container_access_type = "private"
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