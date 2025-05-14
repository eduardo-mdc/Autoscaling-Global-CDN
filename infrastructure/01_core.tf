// 01_core.tf - Core infrastructure (resource group, networking)

// Resource group for the entire infrastructure
resource "azurerm_resource_group" "cdn_rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

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

// Network Security Group for Admin VM
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

// Network Security Group for zone nodes
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

// NSG associations for subnets
resource "azurerm_subnet_network_security_group_association" "admin_nsg_association" {
  subnet_id                 = azurerm_subnet.admin_subnet.id
  network_security_group_id = azurerm_network_security_group.admin_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "europe_nsg_association" {
  subnet_id                 = azurerm_subnet.europe_subnet.id
  network_security_group_id = azurerm_network_security_group.zone_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "america_nsg_association" {
  subnet_id                 = azurerm_subnet.america_subnet.id
  network_security_group_id = azurerm_network_security_group.zone_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "asia_nsg_association" {
  subnet_id                 = azurerm_subnet.asia_subnet.id
  network_security_group_id = azurerm_network_security_group.zone_nsg.id
}

// Log Analytics workspace for monitoring
resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "cdn-log-analytics"
  location            = azurerm_resource_group.cdn_rg.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}