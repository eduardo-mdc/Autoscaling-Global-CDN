variable "resource_group_name" {
  type        = string
  description = "Prefix for resource names"
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
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the admin host will reside"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for admin host placement"
}
