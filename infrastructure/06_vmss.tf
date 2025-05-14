// EUROPE REGION

// Public IP for Europe Load Balancer
resource "azurerm_public_ip" "europe_lb_ip" {
  name                = "europe-lb-public-ip"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  allocation_method   = "Static"
  domain_name_label   = "europe-cdn"
  sku                 = "Standard"

  tags = var.tags
}

// Load Balancer for Europe
resource "azurerm_lb" "europe_lb" {
  name                = "europe-lb"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "europe-lb-frontend"
    public_ip_address_id = azurerm_public_ip.europe_lb_ip.id
  }

  tags = var.tags
}

// Backend pool for Europe Load Balancer
resource "azurerm_lb_backend_address_pool" "europe_backend_pool" {
  name            = "europe-backend-pool"
  loadbalancer_id = azurerm_lb.europe_lb.id
}

// Health probe for Europe Load Balancer
resource "azurerm_lb_probe" "europe_health_probe" {
  name                = "europe-health-probe"
  loadbalancer_id     = azurerm_lb.europe_lb.id
  protocol            = "Http"
  port                = 80
  request_path        = "/health"
  interval_in_seconds = 15
  number_of_probes    = 2
}

// Load balancer rule for Europe
resource "azurerm_lb_rule" "europe_lb_rule" {
  name                           = "europe-lb-rule-http"
  loadbalancer_id                = azurerm_lb.europe_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "europe-lb-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.europe_backend_pool.id]
  probe_id                       = azurerm_lb_probe.europe_health_probe.id
  disable_outbound_snat          = true
  idle_timeout_in_minutes        = 4
}

// VMSS for Europe
resource "azurerm_linux_virtual_machine_scale_set" "europe_vmss" {
  name                = "europe-vmss"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  location            = "westeurope"
  sku                 = var.vm_size
  instances           = 1
  admin_username      = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_keys[0])
  }

  source_image_id = data.azurerm_image.europe_image.id

  os_disk {
    storage_account_type = var.os_disk_storage_account_type
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "europe-vmss-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.europe_subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.europe_backend_pool.id]
    }
  }




  tags = var.tags
}

// Autoscale settings for Europe VMSS
resource "azurerm_monitor_autoscale_setting" "europe_autoscale" {
  name                = "europe-autoscale"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  location            = "westeurope"
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.europe_vmss.id

  profile {
    name = "europe-default-profile"

    capacity {
      default = 1
      minimum = 1
      maximum = 5
    }

    // Scale out rule - high CPU usage
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.europe_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    // Scale in rule - low CPU usage
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.europe_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
  tags = var.tags
}

// AMERICA REGION

// Public IP for America Load Balancer
resource "azurerm_public_ip" "america_lb_ip" {
  name                = "america-lb-public-ip"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  allocation_method   = "Static"
  domain_name_label   = "america-cdn"
  sku                 = "Standard"

  tags = var.tags
}

// Load Balancer for America
resource "azurerm_lb" "america_lb" {
  name                = "america-lb"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "america-lb-frontend"
    public_ip_address_id = azurerm_public_ip.america_lb_ip.id
  }

  tags = var.tags
}

// Backend pool for America Load Balancer
resource "azurerm_lb_backend_address_pool" "america_backend_pool" {
  name            = "america-backend-pool"
  loadbalancer_id = azurerm_lb.america_lb.id
}

// Health probe for America Load Balancer
resource "azurerm_lb_probe" "america_health_probe" {
  name                = "america-health-probe"
  loadbalancer_id     = azurerm_lb.america_lb.id
  protocol            = "Http"
  port                = 80
  request_path        = "/health"
  interval_in_seconds = 15
  number_of_probes    = 2
}

// Load balancer rule for America
resource "azurerm_lb_rule" "america_lb_rule" {
  name                           = "america-lb-rule-http"
  loadbalancer_id                = azurerm_lb.america_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "america-lb-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.america_backend_pool.id]
  probe_id                       = azurerm_lb_probe.america_health_probe.id
  disable_outbound_snat          = true
  idle_timeout_in_minutes        = 4
}

// VMSS for America
resource "azurerm_linux_virtual_machine_scale_set" "america_vmss" {
  name                = "america-vmss"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  location            = "eastus"
  sku                 = var.vm_size
  instances           = 1
  admin_username      = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_keys[0])
  }
  source_image_id = data.azurerm_image.america_image.id

  os_disk {
    storage_account_type = var.os_disk_storage_account_type
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "america-vmss-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.america_subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.america_backend_pool.id]
    }
  }


  tags = var.tags
}

// Autoscale settings for America VMSS
resource "azurerm_monitor_autoscale_setting" "america_autoscale" {
  name                = "america-autoscale"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  location            = "eastus"
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.america_vmss.id

  profile {
    name = "america-default-profile"

    capacity {
      default = 1
      minimum = 1
      maximum = 5
    }

    // Scale out rule - high CPU usage
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.america_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    // Scale in rule - low CPU usage
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.america_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  tags = var.tags
}

// ASIA REGION

// Public IP for Asia Load Balancer
resource "azurerm_public_ip" "asia_lb_ip" {
  name                = "asia-lb-public-ip"
  location            = "southeastasia"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  allocation_method   = "Static"
  domain_name_label   = "asia-cdn"
  sku                 = "Standard"

  tags = var.tags
}

// Load Balancer for Asia
resource "azurerm_lb" "asia_lb" {
  name                = "asia-lb"
  location            = "southeastasia"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "asia-lb-frontend"
    public_ip_address_id = azurerm_public_ip.asia_lb_ip.id
  }

  tags = var.tags
}

// Backend pool for Asia Load Balancer
resource "azurerm_lb_backend_address_pool" "asia_backend_pool" {
  name            = "asia-backend-pool"
  loadbalancer_id = azurerm_lb.asia_lb.id
}

// Health probe for Asia Load Balancer
resource "azurerm_lb_probe" "asia_health_probe" {
  name                = "asia-health-probe"
  loadbalancer_id     = azurerm_lb.asia_lb.id
  protocol            = "Http"
  port                = 80
  request_path        = "/health"
  interval_in_seconds = 15
  number_of_probes    = 2
}

// Load balancer rule for Asia
resource "azurerm_lb_rule" "asia_lb_rule" {
  name                           = "asia-lb-rule-http"
  loadbalancer_id                = azurerm_lb.asia_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "asia-lb-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.asia_backend_pool.id]
  probe_id                       = azurerm_lb_probe.asia_health_probe.id
  disable_outbound_snat          = true
  idle_timeout_in_minutes        = 4
}

// VMSS for Asia
resource "azurerm_linux_virtual_machine_scale_set" "asia_vmss" {
  name                = "asia-vmss"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  location            = "southeastasia"
  sku                 = var.vm_size
  instances           = 1
  admin_username      = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_keys[0])
  }

  source_image_id = data.azurerm_image.asia_image.id

  os_disk {
    storage_account_type = var.os_disk_storage_account_type
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "asia-vmss-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.asia_subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.asia_backend_pool.id]
    }
  }


  tags = var.tags
}

// Autoscale settings for Asia VMSS
resource "azurerm_monitor_autoscale_setting" "asia_autoscale" {
  name                = "asia-autoscale"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  location            = "southeastasia"
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.asia_vmss.id

  profile {
    name = "asia-default-profile"

    capacity {
      default = 1
      minimum = 1
      maximum = 5
    }

    // Scale out rule - high CPU usage
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.asia_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    // Scale in rule - low CPU usage
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.asia_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  tags = var.tags
}