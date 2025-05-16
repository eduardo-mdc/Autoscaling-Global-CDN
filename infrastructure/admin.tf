// Public IP for Admin VM
resource "azurerm_public_ip" "admin_public_ip" {
  name                = "admin-public-ip"
  location            = azurerm_resource_group.cdn_rg.location
  resource_group_name = azurerm_resource_group.cdn_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
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

  // Custom data for initial setup (base64 encoded)
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    # Initial setup for Admin VM
    dnf update -y
    dnf install -y wget curl jq azure-cli

    # Install Azure CLI for container management
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash

    # Create management script
    cat > /home/${var.admin_username}/manage-container-apps.sh << 'SCRIPT'
    #!/bin/bash
    # Script to manage Container Apps

    # Print usage information
    function print_usage() {
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  list                   - List all Container Apps"
      echo "  status [region]        - Show status of apps in a region (europe, america, asia)"
      echo "  scale [region] [min] [max] - Scale app in a region to min/max replicas"
      echo "  logs [region]          - Show logs for app in a region"
      echo "  help                   - Show this help message"
    }

    # List all apps
    function list_apps() {
      echo "Listing all Container Apps..."
      az containerapp list --resource-group ${var.resource_group_name} --output table
    }

    # Show app status
    function show_status() {
      local region=$1
      local app_name=""

      case $region in
        europe)
          app_name="europe-cdn-app"
          ;;
        america)
          app_name="america-cdn-app"
          ;;
        asia)
          app_name="asia-cdn-app"
          ;;
        *)
          echo "Invalid region. Use: europe, america, or asia"
          exit 1
          ;;
      esac

      echo "Status for $app_name:"
      az containerapp revision list --name $app_name --resource-group ${var.resource_group_name} --output table
    }

    # Scale app
    function scale_app() {
      local region=$1
      local min=$2
      local max=$3
      local app_name=""

      case $region in
        europe)
          app_name="europe-cdn-app"
          ;;
        america)
          app_name="america-cdn-app"
          ;;
        asia)
          app_name="asia-cdn-app"
          ;;
        *)
          echo "Invalid region. Use: europe, america, or asia"
          exit 1
          ;;
      esac

      echo "Scaling $app_name to min=$min replicas, max=$max replicas..."
      az containerapp update --name $app_name --resource-group ${var.resource_group_name} --min-replicas $min --max-replicas $max
    }

    # Show logs
    function show_logs() {
      local region=$1
      local app_name=""

      case $region in
        europe)
          app_name="europe-cdn-app"
          ;;
        america)
          app_name="america-cdn-app"
          ;;
        asia)
          app_name="asia-cdn-app"
          ;;
        *)
          echo "Invalid region. Use: europe, america, or asia"
          exit 1
          ;;
      esac

      echo "Logs for $app_name:"
      az containerapp logs show --name $app_name --resource-group ${var.resource_group_name} --follow
    }

    # Main script logic
    case $1 in
      list)
        list_apps
        ;;
      status)
        if [ -z "$2" ]; then
          echo "Error: Region required"
          print_usage
          exit 1
        fi
        show_status $2
        ;;
      scale)
        if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
          echo "Error: Region, min replicas, and max replicas required"
          print_usage
          exit 1
        fi
        scale_app $2 $3 $4
        ;;
      logs)
        if [ -z "$2" ]; then
          echo "Error: Region required"
          print_usage
          exit 1
        fi
        show_logs $2
        ;;
      help|--help|-h)
        print_usage
        ;;
      *)
        echo "Unknown option: $1"
        print_usage
        exit 1
        ;;
    esac
    SCRIPT

    # Make the management script executable
    chmod +x /home/${var.admin_username}/manage-container-apps.sh
    chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/manage-container-apps.sh

    # Create README file for admin
    cat > /home/${var.admin_username}/README.txt << EOF2
    Azure Container Apps CDN - Admin Server
    ======================================

    This server is used to manage your global CDN infrastructure deployed with Azure Container Apps.

    Management Script:
    - /home/${var.admin_username}/manage-container-apps.sh: Script to manage your Container Apps

    Run 'az login' to authenticate with Azure before using the management script.

    Example commands:
    - List all Container Apps:
      ./manage-container-apps.sh list

    - Show status of Europe region:
      ./manage-container-apps.sh status europe

    - Scale America region to 2-5 replicas:
      ./manage-container-apps.sh scale america 2 5

    - Show logs for Asia region:
      ./manage-container-apps.sh logs asia

    Each region runs an independent nginx container with auto-scaling capabilities.
    EOF2

    chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/README.txt

    echo 'Initial configuration complete'
  EOF
  )

  tags = var.tags
}