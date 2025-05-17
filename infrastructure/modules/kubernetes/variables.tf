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
  description = "VPC ID where the Kubernetes cluster will be created"
}

variable "min_nodes" {
  type        = number
  description = "Minimum number of nodes in the Kubernetes cluster"
}

variable "max_nodes" {
  type        = number
  description = "Maximum number of nodes in the Kubernetes cluster"
}

variable "admin_ssh_fingerprint" {
  type        = string
  description = "Fingerprint of admin SSH key for node access"
}

variable "node_size" {
  type        = string
  description = "Size of Kubernetes nodes"
  default     = "s-1vcpu-2gb"  # Smallest size for DOKS nodes
}