variable "project_name" {
  description = "Prefix for resource names"
  type        = string
}

variable "admin_username" {
  description = "Username to configure on the admin instance"
  type        = string
  default     = "admin"
}

variable "ssh_public_key" {
  description = "SSH public key content (not path)"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for provisioning"
  type        = string
}

variable "instance_type" {
  description = "Scaleway instance type for admin server"
  type        = string
  default     = "DEV1-S"  # Use a smaller instance type to avoid quota issues
}

variable "instance_image" {
  description = "Scaleway instance image ID for admin server"
  type        = string
  default     = "ubuntu_focal"
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 20
}

variable "admin_allowed_ip" {
  description = "CIDR range allowed to access admin server"
  type        = string
  default     = "0.0.0.0/0"  # Better to restrict this in production
}

variable "private_network_id" {
  description = "ID of the private network to connect to"
  type        = string
}

variable "kubeconfig_paris" {
  description = "Kubeconfig for Paris cluster"
  type        = string
  sensitive   = true
}

variable "kubeconfig_amsterdam" {
  description = "Kubeconfig for Amsterdam cluster"
  type        = string
  sensitive   = true
}

variable "kubeconfig_warsaw" {
  description = "Kubeconfig for Warsaw cluster"
  type        = string
  sensitive   = true
}