
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

// Admin VM Variables
variable "vm_size" {
  description = "Size of the admin virtual machine"
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

// Network Variables
variable "vnet_address_space" {
  description = "Address space for the admin virtual network"
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
    europe  = "10.1.1.0/24"
    america = "10.2.1.0/24"
    asia    = "10.3.1.0/24"
  }
}

// Container Apps Variables
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

variable "cpu" {
  description = "CPU allocation for container apps (in whole cores)"
  type        = number
  default     = 0.5
}

variable "memory" {
  description = "Memory allocation for container apps (in GB)"
  type        = string
  default     = "1Gi"
}

// Regional Configuration
variable "regions" {
  description = "Configuration for each region"
  type = map(object({
    location = string
    vnet_address_space = string
    subnet_prefix = string
    container_apps_subnet_prefix = string
  }))
  default = {
    europe = {
      location = "westeurope"
      vnet_address_space = "10.1.0.0/16"
      subnet_prefix = "10.1.1.0/24"
      container_apps_subnet_prefix = "10.1.2.0/23"  // /23 subnet for Container Apps (512 IPs)
    }
    america = {
      location = "eastus"
      vnet_address_space = "10.2.0.0/16"
      subnet_prefix = "10.2.1.0/24"
      container_apps_subnet_prefix = "10.2.2.0/23"  // /23 subnet for Container Apps (512 IPs)
    }
    asia = {
      location = "southeastasia"
      vnet_address_space = "10.3.0.0/16"
      subnet_prefix = "10.3.1.0/24"
      container_apps_subnet_prefix = "10.3.2.0/23"  // /23 subnet for Container Apps (512 IPs)
    }
  }
}