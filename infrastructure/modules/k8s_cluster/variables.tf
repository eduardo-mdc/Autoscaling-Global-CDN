variable "project_id" {
  description = "Scaleway project ID"
  type        = string
}

variable "project_name" {
  description = "Prefix for resource names"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes Version"
  type        = string
}

variable "max_size" {
  description = "Maximum number of nodes in the pool"
  type        = number
  default     = 3
}

variable "cni" {
  description = "CNI plugin to use"
  type        = string
  default     = "cilium"
}

variable "min_size" {
  description = "Minimum number of nodes in the pool"
  type        = number
  default     = 0
}

variable "size" {
  description = "Initial Size of the pool"
  type        = number
  default     = 2
}

variable "vpc_id" {
  description = "ID of the VPC (private network) to attach the cluster to"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR range of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "region" {
  description = "Scaleway region for this cluster"
  type        = string
}

variable "node_type" {
  description = "Machine type for worker nodes"
  type        = string
  default     = "DEV1-M"
}

variable "admin_server_ip" {
  description = "IP address of the admin server that needs access to the K8s API"
  type        = string
  default     = ""
}

variable "min_node_count" {
  description = "Minimum number of nodes in the pool"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes in the pool"
  type        = number
  default     = 3
}