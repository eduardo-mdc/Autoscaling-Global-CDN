# terraform/modules/admin/variables.tf - Fixed Admin Variables

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "region" {
  description = "GCP region for admin VM"
  type        = string
}

variable "zone" {
  description = "GCP zone for admin VM"
  type        = string
}

variable "machine_type" {
  description = "Machine type for admin VM"
  type        = string
  default     = "e2-standard-2"
}

variable "admin_username" {
  description = "Username for admin VM"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "SSH public key content for admin VM"
  type        = string
}

variable "allowed_ssh_ranges" {
  description = "CIDR ranges allowed to SSH to admin VM"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "region_numbers" {
  description = "Map of regions to their numeric identifiers for CIDR calculation"
  type        = map(number)
  default     = {}
}

variable "all_regions" {
  description = "List of all regions where GKE clusters are deployed"
  type        = list(string)
  default     = []
}

# Domain and SSL configuration
variable "domain_name" {
  description = "Domain name for admin webapp (e.g., example.com). Leave empty to disable SSL."
  type        = string
  default     = ""
}

variable "dns_zone_name" {
  description = "Name of the DNS zone (required if domain_name is provided)"
  type        = string
  default     = ""
}

# Admin subnet CIDR (to avoid circular dependency)
variable "admin_subnet_cidr" {
  description = "CIDR range for admin subnet"
  type        = string
  default     = "10.250.0.0/24"
}

# Health check configuration
variable "health_check_path" {
  description = "Path for health checks"
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 10
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

# Security configuration
variable "enable_os_login" {
  description = "Enable OS Login for enhanced security"
  type        = bool
  default     = false
}

variable "enable_shielded_vm" {
  description = "Enable Shielded VM features"
  type        = bool
  default     = true
}