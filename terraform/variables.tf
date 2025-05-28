# terraform/variables.tf

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
  default     = ["europe-west2", "us-south1", "asia-southeast1"]
}

variable "zones" {
  description = "GCP zones to deploy to (one per region) - auto-generated if not specified"
  type        = map(string)
  default     = {}
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
  default     = "e2-medium"
}

variable "node_disk_size_gb" {
  description = "Disk size for GKE nodes in GB"
  type        = number
  default     = 40
}

variable "node_disk_type" {
  description = "Disk type for GKE nodes"
  type        = string
  default     = "pd-standard"
}

variable "admin_machine_type" {
  description = "Machine type for admin VM"
  type        = string
  default     = "e2-standard-2"
}

variable "admin_username" {
  description = "Username to configure on the admin VM"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for the admin host"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "enable_cdn" {
  description = "Enable Cloud CDN for caching static content"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name to use for global load balancing (e.g., example.com). Leave empty to skip domain setup."
  type        = string
  default     = "adm-cdn.pt"
}

variable "enable_regional_subdomains" {
  description = "Whether to create regional subdomains (europe.example.com, us.example.com, etc.)"
  type        = bool
  default     = false
}

variable "enable_caa_records" {
  description = "Whether to create CAA records for certificate authority authorization"
  type        = bool
  default     = true
}

variable "additional_domains" {
  description = "Additional domains to include in the SSL certificate"
  type        = list(string)
  default     = []
}

variable "master_bucket_location" {
  description = "Location for the master content bucket (multi-regional: US, EU, or ASIA)"
  type        = string
  default     = "EU"

  validation {
    condition = contains([
      "US", "EU", "ASIA"
    ], upper(var.master_bucket_location))
    error_message = "Master bucket location must be a multi-regional location: US, EU, or ASIA."
  }
}

# Storage Configuration Variables
variable "environment" {
  description = "Environment label for resources"
  type        = string
  default     = "production"
}

variable "enable_storage_versioning" {
  description = "Enable versioning on master content bucket"
  type        = bool
  default     = true
}

variable "enable_regional_storage_versioning" {
  description = "Enable versioning on regional cache buckets"
  type        = bool
  default     = false
}

variable "enable_storage_lifecycle" {
  description = "Enable lifecycle management on master bucket"
  type        = bool
  default     = false
}

variable "enable_cache_lifecycle" {
  description = "Enable lifecycle management on regional cache buckets"
  type        = bool
  default     = false
}

variable "enable_bucket_notifications" {
  description = "Enable bucket notifications for content sync automation (future use)"
  type        = bool
  default     = false
}

variable "storage_public_access_prevention" {
  description = "Public access prevention setting for storage buckets"
  type        = string
  default     = "enforced"

  validation {
    condition = contains([
      "enforced",
      "inherited"
    ], var.storage_public_access_prevention)
    error_message = "Public access prevention must be 'enforced' or 'inherited'."
  }
}

variable "storage_force_destroy" {
  description = "Allow bucket deletion even when not empty (USE WITH CAUTION - for development only)"
  type        = bool
  default     = false
}

variable "admin_iap_members" {
  description = "List of members that can access the admin service via IAP"
  type        = list(string)
  default     = ["user:admin@example.com"]
}

variable "oauth_client_id" {
  description = "OAuth client ID for IAP"
  type        = string
}

variable "oauth_client_secret" {
  description = "OAuth client secret for IAP"
  type        = string
  sensitive   = true
}

variable "admin_allowed_ips" {
    description = "List of CIDR ranges allowed to SSH to the admin VM"
    type        = list(string)
    default     = ["0.0.0.0/0"]  # Change this to restrict access in production
}

# Hot/Cold cluster configuration
variable "hot_regions" {
  description = "Regions that should be always active (hot)"
  type        = list(string)
  default     = ["europe-west2", "us-south1"]  # EU and Americas
}

variable "cold_regions" {
  description = "Regions that should be scaled down by default (cold)"
  type        = list(string)
  default     = ["asia-southeast1"]  # APAC
}

# Hot cluster configuration
variable "hot_cluster_config" {
  description = "Configuration for hot clusters"
  type = object({
    min_nodes         = number
    max_nodes         = number
    initial_nodes     = number
    machine_type      = string
    disk_size_gb      = number
    disk_type         = string
  })
  default = {
    min_nodes         = 1   # Always running
    max_nodes         = 3   # High scale capacity
    initial_nodes     = 1   # Start with 1 nodes
    machine_type      = "e2-standard-2"  # More powerful for active traffic
    disk_size_gb      = 40
    disk_type         = "pd-standard"
  }
}

# Cold cluster configuration
variable "cold_cluster_config" {
  description = "Configuration for cold clusters"
  type = object({
    min_nodes         = number
    max_nodes         = number
    initial_nodes     = number
    machine_type      = string
    disk_size_gb      = number
    disk_type         = string
  })
  default = {
    min_nodes         = 0    # Scale to zero
    max_nodes         = 2    # Moderate scale capacity
    initial_nodes     = 0    # Start with 0 nodes
    machine_type      = "e2-standard-2"  # Smaller for cost efficiency
    disk_size_gb      = 40
    disk_type         = "pd-standard"
  }
}

# Auto-scaling behavior
variable "enable_cluster_autoscaling" {
  description = "Enable advanced cluster autoscaling"
  type        = bool
  default     = true
}

variable "cold_cluster_scale_up_trigger" {
  description = "Trigger mechanism for cold cluster scale-up"
  type        = string
  default     = "geographic_traffic"  # Options: geographic_traffic, latency_based, manual, scheduled
}

# Traffic-based scaling thresholds
variable "scale_up_thresholds" {
  description = "Thresholds for scaling up cold clusters based on traffic"
  type = object({
    asia_requests_per_10min      = number  # Scale up if Asia traffic > this many requests per 10min
    asia_traffic_percentage      = number  # Scale up if Asia traffic > this % of total
    latency_threshold_ms         = number  # Scale up if latency to hot clusters > this
    min_total_requests           = number  # Only scale if total traffic > this threshold
    scale_down_asia_requests     = number  # Scale down if Asia traffic < this
    scale_down_latency_ms        = number  # Scale down if latency < this
  })
  default = {
    asia_requests_per_10min      = 50     # 50 requests from Asia in 10 minutes
    asia_traffic_percentage      = 10     # 10% of total traffic from Asia
    latency_threshold_ms         = 200    # 500ms latency threshold
    min_total_requests           = 100    # Need at least 100 total requests
    scale_down_asia_requests     = 10     # Scale down if < 10 Asia requests
    scale_down_latency_ms        = 100    # Scale down if latency < 200ms
  }
}