// variables.tf Terraform variables for Azure CDN infrastructure, dont change values here, define them in terraform.tfvars file
// or pass them as command line arguments when running Terraform commands

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
    role        = "admin"
    project     = "global-cdn"
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

// "os_disk_storage_account_type" defines the type of storage account for the OS disk
// Available storage account types
// "Standard_LRS" - Standard Locally Redundant Storage (LRS)
// "Standard_GRS" - Standard Geo-Redundant Storage (GRS)
// "Standard_RAGRS" - Standard Read-Access Geo-Redundant Storage (RA-GRS)
// "Standard_ZRS" - Standard Zone-Redundant Storage (ZRS)
// "Premium_LRS" - Premium Locally Redundant Storage (LRS)
// "Premium_ZRS" - Premium Zone-Redundant Storage (ZRS)
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
    admin  = string
    europe = string
    america = string
    asia   = string
  })
  default = {
    admin  = "10.0.0.0/24"
    europe = "10.0.1.0/24"
    america = "10.0.2.0/24"
    asia   = "10.0.3.0/24"
  }
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}