
// Network interface for image builder VM
resource "azurerm_network_interface" "image_builder_nic" {
  name                = "image-builder-nic"
  location            = azurerm_resource_group.cdn_rg.location
  resource_group_name = azurerm_resource_group.cdn_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.admin_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.image_builder_ip.id
  }
}

// Public IP for image builder VM
resource "azurerm_public_ip" "image_builder_ip" {
  name                = "image-builder-ip"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  location            = azurerm_resource_group.cdn_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

// Image builder VM
resource "azurerm_linux_virtual_machine" "image_builder" {
  name                  = "image-builder"
  resource_group_name   = azurerm_resource_group.cdn_rg.name
  location              = azurerm_resource_group.cdn_rg.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.image_builder_nic.id]
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_keys[0])
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = var.os_image.publisher
    offer     = var.os_image.offer
    sku       = var.os_image.sku
    version   = var.os_image.version
  }

  tags = var.tags

  // Wait for SSH to be available with retry logic
  provisioner "local-exec" {
    command = "bash -c 'echo \"Waiting for SSH...\"; until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes ${var.admin_username}@${azurerm_public_ip.image_builder_ip.ip_address} exit 2>/dev/null; do echo \"Retrying...\"; sleep 10; done; echo \"SSH is ready\"'"
  }

  // Run Ansible playbook directly on the VM
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.admin_username} -i '${azurerm_public_ip.image_builder_ip.ip_address},' playbooks/setup-base-image.yaml"
  }
}

// Generalize VM and create image after Ansible configuration
resource "null_resource" "generalize_vm" {
  depends_on = [azurerm_linux_virtual_machine.image_builder]

  // Deprovision the VM
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no ${var.admin_username}@${azurerm_public_ip.image_builder_ip.ip_address} 'sudo waagent -force -deprovision+user && export HISTSIZE=0 && sync'"
  }

  // Wait a moment for operations to complete
  provisioner "local-exec" {
    command = "sleep 30"
  }

  // Deallocate the VM
  provisioner "local-exec" {
    command = "az vm deallocate --resource-group ${azurerm_resource_group.cdn_rg.name} --name ${azurerm_linux_virtual_machine.image_builder.name}"
  }

  // Generalize the VM
  provisioner "local-exec" {
    command = "az vm generalize --resource-group ${azurerm_resource_group.cdn_rg.name} --name ${azurerm_linux_virtual_machine.image_builder.name}"
  }
}
// Create image in the source VM's region only
resource "azurerm_image" "source_image" {
  name                = "cdn-nginx-image-source"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  location            = azurerm_resource_group.cdn_rg.location  // Same as VM
  source_virtual_machine_id = azurerm_linux_virtual_machine.image_builder.id
  hyper_v_generation = "V2"
  depends_on = [null_resource.generalize_vm]
  tags       = var.tags
}

// Use null_resource to copy the image to other regions using Azure CLI
resource "null_resource" "copy_image_to_europe" {
  depends_on = [azurerm_image.source_image]

  provisioner "local-exec" {
    # Using a single line command to avoid syntax issues
    command = "az image create --resource-group ${azurerm_resource_group.cdn_rg.name} --name cdn-nginx-image-europe --location westeurope --source ${azurerm_image.source_image.id} --hyper-v-generation V2 --tags environment=production owner=infrastructure-team project=global-cdn role=cdn"
  }
}

resource "null_resource" "copy_image_to_america" {
  depends_on = [azurerm_image.source_image]

  provisioner "local-exec" {
    # Using a single line command to avoid syntax issues
    command = "az image create --resource-group ${azurerm_resource_group.cdn_rg.name} --name cdn-nginx-image-america --location eastus --source ${azurerm_image.source_image.id} --hyper-v-generation V2 --tags environment=production owner=infrastructure-team project=global-cdn role=cdn"
  }
}

resource "null_resource" "copy_image_to_asia" {
  depends_on = [azurerm_image.source_image]

  provisioner "local-exec" {
    # Using a single line command to avoid syntax issues
    command = "az image create --resource-group ${azurerm_resource_group.cdn_rg.name} --name cdn-nginx-image-asia --location southeastasia --source ${azurerm_image.source_image.id} --hyper-v-generation V2 --tags environment=production owner=infrastructure-team project=global-cdn role=cdn"
  }
}

// Data sources to retrieve the copied images
data "azurerm_image" "europe_image" {
  name                = "cdn-nginx-image-europe"
  resource_group_name = azurerm_resource_group.cdn_rg.name

  # Important: Add this to prevent data source from running before image is created
  depends_on          = [null_resource.copy_image_to_europe]
}

data "azurerm_image" "america_image" {
  name                = "cdn-nginx-image-america"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  depends_on          = [null_resource.copy_image_to_america]
}

data "azurerm_image" "asia_image" {
  name                = "cdn-nginx-image-asia"
  resource_group_name = azurerm_resource_group.cdn_rg.name
  depends_on          = [null_resource.copy_image_to_asia]
}