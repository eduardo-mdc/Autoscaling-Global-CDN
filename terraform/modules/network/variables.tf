variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "region" {
  description = "GCP region to deploy network"
  type        = string
}

variable "region_number" {
  description = "Numeric identifier for this region (for CIDR calculations)"
  type        = number
}

variable "admin_cidr" {
  description = "CIDR range of the admin VM"
  type        = string
}

variable "other_region_cidrs" {
  description = "List of CIDR ranges from other regions"
  type        = list(string)
  default     = []
}