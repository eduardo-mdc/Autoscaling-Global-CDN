# terraform/modules/loadbalancer/variables.tf - Simplified Variables

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "regions" {
  description = "List of GCP regions"
  type        = list(string)
}

variable "domain_name" {
  description = "Domain name to use for global load balancing (e.g., example.com). Leave empty to skip domain setup."
  type        = string
  default     = ""
}

variable "enable_regional_subdomains" {
  description = "Whether to create regional subdomains (europe.example.com, us.example.com, etc.)"
  type        = bool
  default     = false
}

variable "enable_caa_records" {
  description = "Whether to create CAA records for certificate authority authorization"
  type        = bool
  default     = true
}

variable "additional_domains" {
  description = "Additional domains to include in the SSL certificate"
  type        = list(string)
  default     = []
}