variable "project_name" {
  type        = string
  description = "Prefix for resource names"
}

variable "region" {
  type        = string
  description = "Digital Ocean region"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where admin droplet will be created"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to SSH public key to use for admin access"
}

variable "admin_username" {
  type        = string
  description = "Username to configure on the admin host"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to admin resources"
  default     = {}
}

variable "droplet_size" {
  type        = string
  description = "Size of the admin droplet"
  default     = "s-1vcpu-1gb"  # Smallest size, equivalent to t2.micro
}