# Admin Webapp Module Variables

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "admin_domain" {
  description = "Domain for admin webapp (e.g. admin.example.com)"
  type        = string
}

variable "dns_zone_name" {
  description = "Name of the DNS managed zone (leave empty to skip DNS)"
  type        = string
  default     = ""
}

variable "admin_vm_self_link" {
  description = "Self link of the admin VM instance"
  type        = string
}

variable "admin_vm_zone" {
  description = "Zone where admin VM is located"
  type        = string
}

variable "admin_vm_network" {
  description = "Network name where admin VM is located"
  type        = string
}

variable "oauth_client_id" {
  description = "OAuth 2.0 client ID for IAP"
  type        = string
}

variable "oauth_client_secret" {
  description = "OAuth 2.0 client secret for IAP"
  type        = string
  sensitive   = true
}

variable "authorized_users" {
  description = "List of users authorized to access admin webapp via IAP"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.authorized_users) > 0
    error_message = "At least one authorized user must be specified."
  }
}

variable "health_check_path" {
  description = "Path for health check endpoint"
  type        = string
  default     = "/health"
}

variable "backend_timeout" {
  description = "Backend service timeout in seconds"
  type        = number
  default     = 60
}

variable "ssl_certificate_domains" {
  description = "Additional domains for SSL certificate"
  type        = list(string)
  default     = []
}