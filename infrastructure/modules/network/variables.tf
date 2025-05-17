# modules/network_with_gateway/variables.tf
variable "project_name" {
  description = "Prefix for resource names"
  type        = string
}

variable "project_id" {
  description = "Scaleway project ID"
  type        = string
}

variable "region" {
  description = "Scaleway region"
  type        = string
}

variable "zone" {
  description = "Scaleway zone"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = list(string)
  default     = []
}

variable "ipv4_subnet" {
  description = "IPv4 subnet CIDR for the private network (if null, will be auto-assigned)"
  type        = string
  default     = null
}

variable "ipv6_subnet" {
  description = "IPv6 subnet CIDR for the private network (if null, no IPv6)"
  type        = string
  default     = null
}

variable "gw_enabled" {
  description = "Whether to create a public gateway"
  type        = bool
  default     = true
}

variable "gw_reserve_ip" {
  description = "Whether to reserve a flexible IP for the gateway"
  type        = bool
  default     = true
}

variable "gw_type" {
  description = "Type of public gateway"
  type        = string
  default     = "VPC-GW-S"
}

variable "bastion_enabled" {
  description = "Enable SSH bastion on the gateway"
  type        = bool
  default     = true
}

variable "bastion_port" {
  description = "SSH port for the bastion"
  type        = number
  default     = 22
}

variable "smtp_enabled" {
  description = "Enable SMTP on the gateway"
  type        = bool
  default     = false
}

variable "masquerade_enabled" {
  description = "Enable masquerade (NAT) on the gateway"
  type        = bool
  default     = true
}