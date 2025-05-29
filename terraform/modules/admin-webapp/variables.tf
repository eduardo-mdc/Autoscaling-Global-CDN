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



variable "regions" {
  description = "List of regions for regional buckets"
  type        = list(string)
}