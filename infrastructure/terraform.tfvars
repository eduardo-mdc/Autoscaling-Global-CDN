// terraform.tfvars - Custom values defined here for variables.tf

// Region where the resources will be created:
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
location = "westus2"

// "resource_group_name" is the name of the resource group where the resources will be created
resource_group_name = "cdn-resource-group"

// "vm_size" defines the capacity of the virtual machine
// Available sizes for deployment
// VM sizes with ≤4 cores and ≤8GB RAM
// General Purpose
// "Standard_B1ms"   - 1 vCPU, 2GB RAM
// "Standard_B1s"    - 1 vCPU, 1GB RAM
// "Standard_B2s"    - 2 vCPU, 4GB RAM
// "Standard_D1_v2"  - 1 vCPU, 3.5GB RAM
// "Standard_D2_v2"  - 2 vCPU, 7GB RAM
// "Standard_D2_v3"  - 2 vCPU, 8GB RAM
// "Standard_DS1_v2" - 1 vCPU, 3.5GB RAM
// "Standard_DS2_v2" - 2 vCPU, 7GB RAM

// Compute Optimized (optimized for compute-intensive workloads, higher CPU-to-memory ratio)
// "Standard_F1s"    - 1 vCPU, 2GB RAM
// "Standard_F2s"    - 2 vCPU, 4GB RAM
// "Standard_F2s_v2" - 2 vCPU, 4GB RAM
vm_size = "Standard_B2s"

ssh_public_keys = [
  "~/.ssh/id_rsa.pub",
  # Add additional SSH public key paths as needed
  # "~/.ssh/another_key.pub"
]

tags = {
  //environment defines the environment in which the resources are deployed
  environment = "production"
  //role defines the role of the resources in the infrastructure
  role        = "admin"
  //project defines the project to which the resources belong
  project     = "global-cdn"
  //owner defines the owner of the resources
  owner       = "infrastructure-team"
}



master_disk_storage_account_type = "Premium_LRS"
master_disk_size_gb = 100

vnet_address_space = ["10.0.0.0/16"]
subnet_prefixes = {
  admin   = "10.0.0.0/24"
  europe  = "10.0.1.0/24"
  america = "10.0.2.0/24"
  asia    = "10.0.3.0/24"
}