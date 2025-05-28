# terraform/modules/storage/variables.tf
# Variables for the storage module

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "regions" {
  description = "List of GCP regions for regional cache buckets"
  type        = list(string)
}

variable "master_bucket_location" {
  description = "Location for the master content bucket (multi-regional)"
  type        = string
  default     = "US"  # Multi-regional: US, EU, or ASIA

  validation {
    condition = contains([
      "US", "EU", "ASIA",           # Multi-regional
      "us", "eu", "asia"            # Case insensitive
    ], upper(var.master_bucket_location))
    error_message = "Master bucket location must be a multi-regional location: US, EU, or ASIA."
  }
}

variable "environment" {
  description = "Environment label for resources"
  type        = string
  default     = "production"
}

# Versioning Configuration
variable "enable_versioning" {
  description = "Enable versioning on master bucket"
  type        = bool
  default     = true
}

variable "enable_regional_versioning" {
  description = "Enable versioning on regional cache buckets"
  type        = bool
  default     = false  # Usually not needed for cache buckets
}

# Lifecycle Management
variable "enable_lifecycle_management" {
  description = "Enable lifecycle management on master bucket"
  type        = bool
  default     = false  # Disabled by default - manual content management
}

variable "lifecycle_delete_age_days" {
  description = "Number of days after which to delete objects in master bucket"
  type        = number
  default     = 365
}

variable "enable_cache_lifecycle_management" {
  description = "Enable lifecycle management on regional cache buckets"
  type        = bool
  default     = false
}

variable "cache_lifecycle_delete_age_days" {
  description = "Number of days after which to delete objects in cache buckets"
  type        = number
  default     = 90  # Shorter retention for cache buckets
}

# Notification Configuration (for future automation)
variable "enable_bucket_notifications" {
  description = "Enable bucket notifications for automatic sync (future use)"
  type        = bool
  default     = false  # Disabled for manual sync approach
}

# Storage Class Configuration
variable "master_bucket_storage_class" {
  description = "Storage class for master bucket"
  type        = string
  default     = "STANDARD"

  validation {
    condition = contains([
      "STANDARD",
      "NEARLINE",
      "COLDLINE",
      "ARCHIVE"
    ], var.master_bucket_storage_class)
    error_message = "Storage class must be one of: STANDARD, NEARLINE, COLDLINE, ARCHIVE."
  }
}

variable "regional_bucket_storage_class" {
  description = "Storage class for regional cache buckets"
  type        = string
  default     = "STANDARD"

  validation {
    condition = contains([
      "STANDARD",
      "NEARLINE",
      "COLDLINE",
      "ARCHIVE"
    ], var.regional_bucket_storage_class)
    error_message = "Storage class must be one of: STANDARD, NEARLINE, COLDLINE, ARCHIVE."
  }
}

# Public Access Prevention
variable "public_access_prevention" {
  description = "Public access prevention setting for buckets"
  type        = string
  default     = "enforced"

  validation {
    condition = contains([
      "enforced",
      "inherited"
    ], var.public_access_prevention)
    error_message = "Public access prevention must be 'enforced' or 'inherited'."
  }
}

# Bucket Force Destroy (for development)
variable "force_destroy" {
  description = "Allow bucket deletion even when not empty (USE WITH CAUTION)"
  type        = bool
  default     = false
}