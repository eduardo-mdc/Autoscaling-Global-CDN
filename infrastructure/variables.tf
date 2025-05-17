variable "project_name" {
  description = "Prefix for all resources"
  type        = string
  default     = "global-serverless"
}

variable "scw_access_key" {
  description = "Scaleway Access Key"
  type        = string
  sensitive   = true
}

variable "scw_secret_key" {
  description = "Scaleway Secret Key"
  type        = string
  sensitive   = true
}

variable "scw_organization_id" {
  description = "Scaleway Organization ID"
  type        = string
}

variable "scw_project_id" {
  description = "Scaleway Project ID"
  type        = string
}

variable "main_region" {
  description = "Main Scaleway region for the admin server"
  type        = string
  default     = "fr-par"
}

variable "main_zone" {
  description = "Main Scaleway zone for the admin server"
  type        = string
  default     = "fr-par-1"
}

variable "regions" {
  description = "Scaleway regions to deploy to"
  type        = list(string)
  default     = ["fr-par", "nl-ams", "pl-waw"]  # Paris, Amsterdam, Warsaw
}

variable "ssh_public_key" {
  description = "SSH public key content (not path)"
  type        = string
}

variable "admin_username" {
  description = "Username to configure on the admin instance"
  type        = string
  default     = "admin"
}

variable "container_image" {
  description = "Container image to deploy in serverless containers"
  type        = string
  default     = "nginx:latest"  # Default image, same as in your K8s example
}

variable "container_port" {
  description = "Port the container exposes"
  type        = number
  default     = 80
}

variable "min_scale" {
  description = "Minimum number of container instances"
  type        = number
  default     = 1
}

variable "max_scale" {
  description = "Maximum number of container instances"
  type        = number
  default     = 3
}

variable "memory_limit" {
  description = "Memory limit for each container in MB"
  type        = number
  default     = 512
}
