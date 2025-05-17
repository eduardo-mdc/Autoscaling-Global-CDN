variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "credentials_file" {
  description = "Path to the GCP service account credentials JSON file"
  type        = string
  default     = "~/.gcp/credentials.json"
}

variable "project_name" {
  description = "Prefix for all resources (e.g. myapp)"
  type        = string
  default     = "global-http"
}

variable "regions" {
  description = "GCP regions to deploy to"
  type        = list(string)
  default     = ["europe-west4", "us-east1", "asia-southeast1"]  # Netherlands, Virginia, Singapore
}

variable "zones" {
  description = "GCP zones to deploy to (one per region)"
  type        = map(string)
  default     = {
    "europe-west4"    = "europe-west4-a",
    "us-east1"        = "us-east1-b",
    "asia-southeast1" = "asia-southeast1-a"
  }
}

variable "min_nodes" {
  description = "Minimum nodes per GKE cluster"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum nodes per GKE cluster"
  type        = number
  default     = 3
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-2"  # 2 vCPU, 8GB memory
}

variable "node_disk_size_gb" {
  description = "Disk size for GKE nodes in GB"
  type        = number
  default     = 100
}

variable "admin_machine_type" {
  description = "Machine type for admin VM"
  type        = string
  default     = "e2-standard-2"  # 2 vCPU, 8GB memory
}

variable "admin_username" {
  description = "Username to configure on the admin VM"
  type        = string
  default     = "admin"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for the admin host"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "domain_name" {
  description = "Domain name to use for global load balancing"
  type        = string
  default     = ""  # Empty string means no domain will be created
}

variable "enable_cdn" {
  description = "Enable Cloud CDN for caching static content"
  type        = bool
  default     = false
}