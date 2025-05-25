# modules/bastion/variables.tf

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "region" {
  description = "GCP region for bastion host"
  type        = string
}

variable "machine_type" {
  description = "Machine type for bastion host"
  type        = string
  default     = "e2-micro"  # Small instance for bastion
}

variable "admin_username" {
  description = "Username for bastion host"
  type        = string
  default     = "admin"
}

variable "ssh_public_key" {
  description = "SSH public key content for bastion host"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnet_self_link" {
  description = "Self link of the subnet where bastion will be placed"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR range of the admin VM subnet"
  type        = string
}