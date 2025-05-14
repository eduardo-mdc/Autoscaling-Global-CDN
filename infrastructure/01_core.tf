// 01_core.tf - Core infrastructure (resource group, networking)

// Resource group for the entire infrastructure
resource "azurerm_resource_group" "cdn_rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

// Virtual network for admin (central management)
resource "azurerm_virtual_network" "cdn_vnet" {
  name                = "cdn-vnet"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.cdn_rg.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
  tags                = var.tags
}

// Admin subnet
resource "azurerm_subnet" "admin_subnet" {
  name                 = "admin-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.cdn_vnet.name
  address_prefixes     = [var.subnet_prefixes.admin]
}

// Europe Virtual Network (West Europe)
resource "azurerm_virtual_network" "europe_vnet" {
  name                = "europe-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  tags                = var.tags
}

// Europe subnet
resource "azurerm_subnet" "europe_subnet" {
  name                 = "europe-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.europe_vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

// America Virtual Network (East US)
resource "azurerm_virtual_network" "america_vnet" {
  name                = "america-vnet"
  address_space       = ["10.2.0.0/16"]
  location            = "eastus"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  tags                = var.tags
}

// America subnet
resource "azurerm_subnet" "america_subnet" {
  name                 = "america-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.america_vnet.name
  address_prefixes     = ["10.2.1.0/24"]
}

// Asia Virtual Network (Southeast Asia)
resource "azurerm_virtual_network" "asia_vnet" {
  name                = "asia-vnet"
  address_space       = ["10.3.0.0/16"]
  location            = "southeastasia"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  tags                = var.tags
}

// Asia subnet
resource "azurerm_subnet" "asia_subnet" {
  name                 = "asia-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.asia_vnet.name
  address_prefixes     = ["10.3.1.0/24"]
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
      "10.1.1.0/24",  // Europe subnet
      "10.2.1.0/24",  // America subnet
      "10.3.1.0/24"   // Asia subnet
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

// Regional NSGs for each region
resource "azurerm_network_security_group" "europe_nsg" {
  name                = "europe-nsg"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.cdn_rg.name

  // Copy the same rules as zone_nsg
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

  security_rule {
    name                       = "AllowInboundFromAdmin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_prefixes.admin
    destination_address_prefix = "*"
  }

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

  tags = var.tags
}

resource "azurerm_network_security_group" "america_nsg" {
  name                = "america-nsg"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.cdn_rg.name

  // Copy the same rules as zone_nsg
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

  security_rule {
    name                       = "AllowInboundFromAdmin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_prefixes.admin
    destination_address_prefix = "*"
  }

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

  tags = var.tags
}

resource "azurerm_network_security_group" "asia_nsg" {
  name                = "asia-nsg"
  location            = "southeastasia"
  resource_group_name = azurerm_resource_group.cdn_rg.name

  // Copy the same rules as zone_nsg
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

  security_rule {
    name                       = "AllowInboundFromAdmin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_prefixes.admin
    destination_address_prefix = "*"
  }

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

  tags = var.tags
}

// NSG associations for subnets
resource "azurerm_subnet_network_security_group_association" "admin_nsg_association" {
  subnet_id                 = azurerm_subnet.admin_subnet.id
  network_security_group_id = azurerm_network_security_group.admin_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "europe_nsg_association" {
  subnet_id                 = azurerm_subnet.europe_subnet.id
  network_security_group_id = azurerm_network_security_group.europe_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "america_nsg_association" {
  subnet_id                 = azurerm_subnet.america_subnet.id
  network_security_group_id = azurerm_network_security_group.america_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "asia_nsg_association" {
  subnet_id                 = azurerm_subnet.asia_subnet.id
  network_security_group_id = azurerm_network_security_group.asia_nsg.id
}

// VNet peering to connect regional networks with admin network
resource "azurerm_virtual_network_peering" "admin_to_europe" {
  name                      = "admin-to-europe"
  resource_group_name       = azurerm_resource_group.cdn_rg.name
  virtual_network_name      = azurerm_virtual_network.cdn_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.europe_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "europe_to_admin" {
  name                      = "europe-to-admin"
  resource_group_name       = azurerm_resource_group.cdn_rg.name
  virtual_network_name      = azurerm_virtual_network.europe_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.cdn_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "admin_to_america" {
  name                      = "admin-to-america"
  resource_group_name       = azurerm_resource_group.cdn_rg.name
  virtual_network_name      = azurerm_virtual_network.cdn_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.america_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "america_to_admin" {
  name                      = "america-to-admin"
  resource_group_name       = azurerm_resource_group.cdn_rg.name
  virtual_network_name      = azurerm_virtual_network.america_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.cdn_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "admin_to_asia" {
  name                      = "admin-to-asia"
  resource_group_name       = azurerm_resource_group.cdn_rg.name
  virtual_network_name      = azurerm_virtual_network.cdn_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.asia_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "asia_to_admin" {
  name                      = "asia-to-admin"
  resource_group_name       = azurerm_resource_group.cdn_rg.name
  virtual_network_name      = azurerm_virtual_network.asia_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.cdn_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
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