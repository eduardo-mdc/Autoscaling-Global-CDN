# terraform/modules/fleet/variables.tf

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "config_cluster_region" {
  description = "Region of the config cluster (where MCI controller runs)"
  type        = string
}

variable "member_cluster_regions" {
  description = "List of member cluster regions"
  type        = list(string)
}

variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
  default     = ""
}