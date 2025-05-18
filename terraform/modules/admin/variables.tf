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
  default     = "e2-standard-2"  # 2 vCPU, 8GB RAM
}

variable "admin_username" {
  description = "Username for admin VM"
  type        = string
  default     = "admin"
}

variable "ssh_public_key" {
  description = "SSH public key content for admin VM"
  type        = string
}

variable "allowed_ssh_ranges" {
  description = "CIDR ranges allowed to SSH to admin VM"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Not recommended for production
}

variable "vpc_network_links" {
  description = "List of VPC network self links to peer with"
  type        = list(string)
  default     = []
}

variable "all_regions" {
  description = "List of all regions where GKE clusters are deployed"
  type        = list(string)
}