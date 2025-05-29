variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Run service"
  type        = string
}

variable "container_image" {
  description = "Container image for the admin webapp"
  type        = string
  default     = "gcr.io/cloudrun/hello"  # Placeholder - replace with your image
}

variable "master_bucket_name" {
  description = "Name of the master GCS bucket"
  type        = string
}

variable "admin_iap_members" {
    description = "List of members with access to the admin webapp via IAP"
    type        = list(string)
    default     = []
}

variable "support_email" {
  description = "Support email for IAP OAuth consent screen"
  type        = string
  default     = "eduardo.mmd.correia@gmail.com"
}

variable "regions" {
  description = "List of regions for regional buckets"
  type        = list(string)
}