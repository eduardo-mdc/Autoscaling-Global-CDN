// 07_networking_fix.tf - Fixes for outbound connectivity

// NAT Gateways for each region to provide outbound internet access
resource "azurerm_public_ip" "europe_nat_ip" {
  name                = "europe-nat-ip"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "europe_nat" {
  name                    = "europe-nat"
  location                = "westeurope"
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
  location            = "eastus"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "america_nat" {
  name                    = "america-nat"
  location                = "eastus"
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
  location            = "southeastasia"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "asia_nat" {
  name                    = "asia-nat"
  location                = "southeastasia"
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