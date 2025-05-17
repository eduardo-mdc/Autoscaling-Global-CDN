variable "project_name" {
  description = "Prefix for all resources (e.g. myapp)"
  type        = string
  default     = "global-cdn"
}


variable "min_nodes" {
  description = "Minimum node count in Kubernetes cluster"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum node count in Kubernetes cluster"
  type        = number
  default     = 1  # Reduced from 3 to 1 to stay within account limits
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for the admin host"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "admin_username" {
  description = "Username to configure on the admin droplet"
  type        = string
  default     = "admin"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "regions" {
  description = "Digital Ocean regions to deploy to"
  type        = list(string)
  default     = ["ams3", "nyc1", "sgp1"]  # Amsterdam, New York, Singapore
}