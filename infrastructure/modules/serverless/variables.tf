variable "project_name" {
  description = "Prefix for resource names"
  type        = string
}

variable "region" {
  description = "Scaleway region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
  default     = "nginx:latest"
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
  description = "Memory limit in MB"
  type        = number
  default     = 512
}