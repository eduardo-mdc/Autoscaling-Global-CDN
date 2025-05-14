// 02_storage.tf - Simplified storage with master disk


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