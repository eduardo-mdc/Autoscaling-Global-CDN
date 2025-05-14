// variables.tf - Variables for the Terraform configuration

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}


// Available regions for deployment grouped by continent
// Europe
// "northeurope"   - North Europe (Ireland)
// "westeurope"    - West Europe (Netherlands)
// "uksouth"       - UK South
// "ukwest"        - UK West

// America
// "eastus"        - East US (Virginia)
// "eastus2"       - East US 2 (Virginia)
// "centralus"     - Central US (Iowa)
// "westus"        - West US (California)
// "westus2"       - West US 2 (Washington)
// "westus3"       - West US 3 (Arizona)

// Asia
// "eastasia"      - East Asia (Hong Kong)
// "southeastasia" - Southeast Asia (Singapore)
// "japaneast"     - Japan East (Tokyo)
// "australiaeast" - Australia East (New South Wales)
variable "location" {
  description = "Default Azure region"
  type        = string
  default     = "westus2"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "cdn-resource-group"
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B2s"
}

variable "os_image" {
  description = "OS image configuration"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "admincdn"
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for the admin user"
  type        = list(string)
  default     = ["~/.ssh/id_rsa.pub"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    environment = "production"
    role        = "cdn"
    project     = "global-cdn"
    owner       = "infrastructure-team"
  }
}

variable "master_disk_size_gb" {
  description = "Size of the master data disk in GB"
  type        = number
  default     = 100
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 70
}

variable "os_disk_storage_account_type" {
  description = "Storage account type for OS disk"
  type        = string
  default     = "Standard_LRS"
}

variable "master_disk_storage_account_type" {
  description = "Storage account type for master disk"
  type        = string
  default     = "Standard_LRS"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_prefixes" {
  description = "Address prefixes for subnets"
  type = object({
    admin   = string
    europe  = string
    america = string
    asia    = string
  })
  default = {
    admin   = "10.0.0.0/24"
    europe  = "10.0.1.0/24"
    america = "10.0.2.0/24"
    asia    = "10.0.3.0/24"
  }
}

variable "container_image" {
  description = "Docker image for the CDN container"
  type        = string
  default     = "nginx:latest"  // Replace with your custom CDN container image
}

variable "container_cpu" {
  description = "CPU allocation for containers (in cores)"
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Memory allocation for containers"
  type        = string
  default     = "1Gi"
}

variable "min_replicas" {
  description = "Minimum number of container replicas"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of container replicas"
  type        = number
  default     = 5
}