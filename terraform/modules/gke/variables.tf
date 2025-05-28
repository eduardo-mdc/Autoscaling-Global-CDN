variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "region" {
  description = "GCP region for GKE cluster"
  type        = string
}

variable "region_number" {
  description = "Numeric identifier for this region (for CIDR calculations)"
  type        = number
}

variable "network_self_link" {
  description = "Self link of the VPC network"
  type        = string
}

variable "subnet_self_link" {
  description = "Self link of the subnet"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR range of the admin VM"
  type        = string
}

# Hot/Cold cluster configuration
variable "cluster_type" {
  description = "Type of cluster (hot or cold)"
  type        = string
  default     = "hot"

  validation {
    condition     = contains(["hot", "cold"], var.cluster_type)
    error_message = "Cluster type must be either 'hot' or 'cold'."
  }
}

variable "initial_nodes" {
  description = "Initial number of nodes per region"
  type        = number
  default     = 2
}

variable "min_nodes" {
  description = "Minimum number of nodes per region (total across all zones)"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum number of nodes per region (total across all zones)"
  type        = number
  default     = 3
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "node_disk_size_gb" {
  description = "Disk size for GKE nodes in GB"
  type        = number
  default     = 50
}

variable "node_disk_type" {
  description = "Disk type for GKE nodes"
  type        = string
  default     = "pd-standard"
}

variable "enable_monitoring" {
  description = "Enable enhanced monitoring for this cluster"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable enhanced logging for this cluster"
  type        = bool
  default     = true
}

variable "node_locations" {
  description = "List of zones for node deployment within the region"
  type        = list(string)
  default     = []
}