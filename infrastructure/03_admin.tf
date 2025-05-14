// 03_admin.tf - Admin VM and related resources

// Public IP for Admin VM
resource "azurerm_public_ip" "admin_public_ip" {
  name                = "admin-public-ip"
  location            = azurerm_resource_group.cdn_rg.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
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

  // Custom data for initial setup (base64 encoded)
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    # Initial setup for Admin VM
    apt-get update && apt-get install -y nfs-kernel-server nfs-common
    mkdir -p /mnt/master

    # Script will continue setup after Terraform completes
    echo 'Initial configuration complete'
  EOF
  )

  tags = var.tags
}

// Attach the managed disk to admin VM
resource "azurerm_virtual_machine_data_disk_attachment" "master_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.master_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.admin_vm.id
  lun                = "10"
  caching            = "ReadOnly"  // ReadOnly for the master disk
}