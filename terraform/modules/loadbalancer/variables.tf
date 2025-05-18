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

variable "backend_services" {
  description = "Map of backend service groups (typically GKE ingress NEGs)"
  type        = list(string)
}

variable "regional_backend_services" {
  description = "Map of regional backend services"
  type        = map(string)
  default     = {}
}

variable "domain_name" {
  description = "Domain name for load balancing (optional)"
  type        = string
  default     = ""
}

variable "ssl_certificate" {
  description = "Self-link to SSL certificate for HTTPS (optional)"
  type        = string
  default     = ""
}

variable "enable_cdn" {
  description = "Enable Cloud CDN for caching static content"
  type        = bool
  default     = false
}