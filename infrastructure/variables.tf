variable "resource_group_name" {
  description = "Prefix for all resources (e.g. myapp)"
  type        = string
  default     = "global-cdn"
}

variable "cpu" {
  description = "vCPU count for the ECS task"
  type        = number
  default     = 0.5
}

variable "memory" {
  description = "Memory (GB) for the ECS task"
  type        = number
  default     = 0.5
}

variable "min_replicas" {
  description = "Minimum ECS task count"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum ECS task count"
  type        = number
  default     = 3
}

variable "request_count_threshold" {
  description = "ALBRequestCountPerTarget threshold to scale on"
  type        = number
  default     = 100
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for the admin host"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "admin_username" {
  description = "Username to configure on the admin EC2 host"
  type        = string
  default     = "admin"
}

variable "tags" {
  description = "Additional tags to apply to all admin resources"
  type        = map(string)
  default     = {}
}
