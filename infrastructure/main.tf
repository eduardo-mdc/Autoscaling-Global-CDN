// main.tf
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

// Resource group for the entire infrastructure
resource "azurerm_resource_group" "cdn_rg" {
  name     = var.resource_group_name
  location = var.location
}

// ===================================== //
// ===== NETWORK INFRASTRUCTURE ======== //
// ===================================== //

// Virtual network for admin and services
resource "azurerm_virtual_network" "cdn_vnet" {
  name                = "cdn-vnet"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.cdn_rg.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
}

// Admin subnet
resource "azurerm_subnet" "admin_subnet" {
  name                 = "admin-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.cdn_vnet.name
  address_prefixes     = [var.subnet_prefixes.admin]
}

// Europe subnet for zone nodes
resource "azurerm_subnet" "europe_subnet" {
  name                 = "europe-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.cdn_vnet.name
  address_prefixes     = [var.subnet_prefixes.europe]
}

// America subnet for zone nodes
resource "azurerm_subnet" "america_subnet" {
  name                 = "america-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.cdn_vnet.name
  address_prefixes     = [var.subnet_prefixes.america]
}

// Asia subnet for zone nodes
resource "azurerm_subnet" "asia_subnet" {
  name                 = "asia-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.cdn_vnet.name
  address_prefixes     = [var.subnet_prefixes.asia]
}

// Network Security Group for Admin VM (allows outbound to zone nodes)
resource "azurerm_network_security_group" "admin_nsg" {
  name                = "admin-nsg"
  location            = azurerm_resource_group.cdn_rg.location
  resource_group_name = azurerm_resource_group.cdn_rg.name

  // Allow SSH access to admin VM
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "0.0.0.0/0"  // Replace with your management IP range
    destination_address_prefix = "*"
  }

  // Allow outbound to zone nodes
  security_rule {
    name                       = "AllowOutboundToZones"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefixes = [
      var.subnet_prefixes.europe,
      var.subnet_prefixes.america,
      var.subnet_prefixes.asia
    ]
  }
}

// Network Security Group for zone nodes (blocks inbound from everywhere except admin)
resource "azurerm_network_security_group" "zone_nsg" {
  name                = "zone-nsg"
  location            = azurerm_resource_group.cdn_rg.location
  resource_group_name = azurerm_resource_group.cdn_rg.name

  // Block inbound from everywhere except admin
  security_rule {
    name                       = "BlockInboundExceptAdmin"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  // Allow inbound from admin subnet
  security_rule {
    name                       = "AllowInboundFromAdmin"
    priority                   = 100  // Higher priority than the deny rule
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_prefixes.admin
    destination_address_prefix = "*"
  }

  // Allow HTTP/HTTPS inbound for external users
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

// NSG association for Admin subnet
resource "azurerm_subnet_network_security_group_association" "admin_nsg_association" {
  subnet_id                 = azurerm_subnet.admin_subnet.id
  network_security_group_id = azurerm_network_security_group.admin_nsg.id
}

// Public IP for Admin VM
resource "azurerm_public_ip" "admin_public_ip" {
  name                = "admin-public-ip"
  location            = azurerm_resource_group.cdn_rg.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

// Network interface for Admin VM
resource "azurerm_network_interface" "admin_nic" {
  name                = "admin-nic"
  location            = azurerm_resource_group.cdn_rg.location
  resource_group_name = azurerm_resource_group.cdn_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.admin_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.admin_public_ip.id
  }
}

// ===================================== //
// ===== NETWORK INFRASTRUCTURE ======== //
// ===================================== //

// ===================================== //
// ===== ZONE NODES & STORAGE ========== //
// ===================================== //

// Storage account for managed disk
resource "azurerm_storage_account" "cdn_storage" {
  name                     = "cdnmainstorage"  // Must be globally unique
  resource_group_name      = azurerm_resource_group.cdn_rg.name
  location                 = azurerm_resource_group.cdn_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

// Admin VM
resource "azurerm_linux_virtual_machine" "admin_vm" {
  name                = "admin-vm"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  location            = azurerm_resource_group.cdn_rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.admin_nic.id,
  ]

  dynamic "admin_ssh_key" {
    for_each = var.ssh_public_keys
    content {
      username   = var.admin_username
      public_key = file(admin_ssh_key.value)
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_account_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.os_image.publisher
    offer     = var.os_image.offer
    sku       = var.os_image.sku
    version   = var.os_image.version
  }

  tags = var.tags
}

// Managed disk for master data
resource "azurerm_managed_disk" "master_disk" {
  name                 = "master-disk"
  location             = azurerm_resource_group.cdn_rg.location
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  storage_account_type = var.master_disk_storage_account_type
  create_option        = "Empty"
  disk_size_gb         = var.master_disk_size_gb
  
  tags = var.tags
}

// Attach the managed disk to admin VM
resource "azurerm_virtual_machine_data_disk_attachment" "master_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.master_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.admin_vm.id
  lun                = "10"
  caching            = "ReadOnly"  // ReadOnly for the master disk
}

// ===================================== //
// ===== ZONE NODES & STORAGE ========== //
// ===================================== //

// ===================================== //
// ===== OUTPUTS ======================= //
// ===================================== //

// Outputs
output "admin_vm_public_ip" {
  value = azurerm_public_ip.admin_public_ip.ip_address
}

output "admin_vm_private_ip" {
  value = azurerm_network_interface.admin_nic.private_ip_address
}

// ===================================== //
// ===== OUTPUTS ======================= //
// ===================================== //