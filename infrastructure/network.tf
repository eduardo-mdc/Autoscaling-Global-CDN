
// Admin Virtual Network
resource "azurerm_virtual_network" "admin_vnet" {
  name                = "admin-vnet"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.cdn_rg.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
  tags                = var.tags
}

// Admin subnet
resource "azurerm_subnet" "admin_subnet" {
  name                 = "admin-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.admin_vnet.name
  address_prefixes     = [var.subnet_prefixes.admin]
}

// Europe Virtual Network
resource "azurerm_virtual_network" "europe_vnet" {
  name                = "europe-vnet"
  address_space       = [var.regions.europe.vnet_address_space]
  location            = var.regions.europe.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
  tags                = var.tags
}

// Europe subnet
resource "azurerm_subnet" "europe_subnet" {
  name                 = "europe-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.europe_vnet.name
  address_prefixes     = [var.regions.europe.subnet_prefix]
}

// Europe Container Apps subnet - dedicated for Container Apps
resource "azurerm_subnet" "europe_container_apps_subnet" {
  name                 = "europe-container-apps-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.europe_vnet.name
  address_prefixes     = [var.regions.europe.container_apps_subnet_prefix]

  // No delegation here - Container Apps service will manage this
}

// America Virtual Network
resource "azurerm_virtual_network" "america_vnet" {
  name                = "america-vnet"
  address_space       = [var.regions.america.vnet_address_space]
  location            = var.regions.america.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
  tags                = var.tags
}

// America subnet
resource "azurerm_subnet" "america_subnet" {
  name                 = "america-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.america_vnet.name
  address_prefixes     = [var.regions.america.subnet_prefix]
}

// America Container Apps subnet - dedicated for Container Apps
resource "azurerm_subnet" "america_container_apps_subnet" {
  name                 = "america-container-apps-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.america_vnet.name
  address_prefixes     = [var.regions.america.container_apps_subnet_prefix]

  // No delegation here - Container Apps service will manage this
}

// Asia Virtual Network
resource "azurerm_virtual_network" "asia_vnet" {
  name                = "asia-vnet"
  address_space       = [var.regions.asia.vnet_address_space]
  location            = var.regions.asia.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
  tags                = var.tags
}

// Asia subnet
resource "azurerm_subnet" "asia_subnet" {
  name                 = "asia-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.asia_vnet.name
  address_prefixes     = [var.regions.asia.subnet_prefix]
}

// Asia Container Apps subnet - dedicated for Container Apps
resource "azurerm_subnet" "asia_container_apps_subnet" {
  name                 = "asia-container-apps-subnet"
  resource_group_name  = azurerm_resource_group.cdn_rg.name
  virtual_network_name = azurerm_virtual_network.asia_vnet.name
  address_prefixes     = [var.regions.asia.container_apps_subnet_prefix]

  // No delegation here - Container Apps service will manage this
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
    source_address_prefix      = "*"  // Recommended to replace with your specific IP
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
      var.regions.europe.subnet_prefix,
      var.regions.america.subnet_prefix,
      var.regions.asia.subnet_prefix,
      var.regions.europe.container_apps_subnet_prefix,
      var.regions.america.container_apps_subnet_prefix,
      var.regions.asia.container_apps_subnet_prefix
    ]
  }

  tags = var.tags
}

// Regional NSGs
resource "azurerm_network_security_group" "europe_nsg" {
  name                = "europe-nsg"
  location            = var.regions.europe.location
  resource_group_name = azurerm_resource_group.cdn_rg.name

  // Block inbound except from admin
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
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_prefixes.admin
    destination_address_prefix = "*"
  }

  // Allow HTTP/HTTPS for Container Apps
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
    priority                   = 102
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
  location            = var.regions.america.location
  resource_group_name = azurerm_resource_group.cdn_rg.name

  // Block inbound except from admin
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
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_prefixes.admin
    destination_address_prefix = "*"
  }

  // Allow HTTP/HTTPS for Container Apps
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
    priority                   = 102
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
  location            = var.regions.asia.location
  resource_group_name = azurerm_resource_group.cdn_rg.name

  // Block inbound except from admin
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
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_prefixes.admin
    destination_address_prefix = "*"
  }

  // Allow HTTP/HTTPS for Container Apps
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
    priority                   = 102
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

// NSG associations for regular subnets
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
  virtual_network_name      = azurerm_virtual_network.admin_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.europe_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "europe_to_admin" {
  name                      = "europe-to-admin"
  resource_group_name       = azurerm_resource_group.cdn_rg.name
  virtual_network_name      = azurerm_virtual_network.europe_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.admin_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "admin_to_america" {
  name                      = "admin-to-america"
  resource_group_name       = azurerm_resource_group.cdn_rg.name
  virtual_network_name      = azurerm_virtual_network.admin_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.america_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "america_to_admin" {
  name                      = "america-to-admin"
  resource_group_name       = azurerm_resource_group.cdn_rg.name
  virtual_network_name      = azurerm_virtual_network.america_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.admin_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "admin_to_asia" {
  name                      = "admin-to-asia"
  resource_group_name       = azurerm_resource_group.cdn_rg.name
  virtual_network_name      = azurerm_virtual_network.admin_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.asia_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "asia_to_admin" {
  name                      = "asia-to-admin"
  resource_group_name       = azurerm_resource_group.cdn_rg.name
  virtual_network_name      = azurerm_virtual_network.asia_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.admin_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
}

// NAT Gateways for each region to provide outbound internet access
resource "azurerm_public_ip" "europe_nat_ip" {
  name                = "europe-nat-ip"
  location            = var.regions.europe.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "europe_nat" {
  name                    = "europe-nat"
  location                = var.regions.europe.location
  resource_group_name     = azurerm_resource_group.cdn_rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "europe_nat_ip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.europe_nat.id
  public_ip_address_id = azurerm_public_ip.europe_nat_ip.id
}

resource "azurerm_subnet_nat_gateway_association" "europe_nat_subnet_assoc" {
  subnet_id      = azurerm_subnet.europe_subnet.id
  nat_gateway_id = azurerm_nat_gateway.europe_nat.id
}

// America NAT Gateway
resource "azurerm_public_ip" "america_nat_ip" {
  name                = "america-nat-ip"
  location            = var.regions.america.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "america_nat" {
  name                    = "america-nat"
  location                = var.regions.america.location
  resource_group_name     = azurerm_resource_group.cdn_rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "america_nat_ip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.america_nat.id
  public_ip_address_id = azurerm_public_ip.america_nat_ip.id
}

resource "azurerm_subnet_nat_gateway_association" "america_nat_subnet_assoc" {
  subnet_id      = azurerm_subnet.america_subnet.id
  nat_gateway_id = azurerm_nat_gateway.america_nat.id
}

// Asia NAT Gateway
resource "azurerm_public_ip" "asia_nat_ip" {
  name                = "asia-nat-ip"
  location            = var.regions.asia.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "asia_nat" {
  name                    = "asia-nat"
  location                = var.regions.asia.location
  resource_group_name     = azurerm_resource_group.cdn_rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "asia_nat_ip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.asia_nat.id
  public_ip_address_id = azurerm_public_ip.asia_nat_ip.id
}

resource "azurerm_subnet_nat_gateway_association" "asia_nat_subnet_assoc" {
  subnet_id      = azurerm_subnet.asia_subnet.id
  nat_gateway_id = azurerm_nat_gateway.asia_nat.id
}