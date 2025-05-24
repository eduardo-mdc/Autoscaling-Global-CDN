variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "project_name" {
  description = "The name of the project, used for naming resources"
  type        = string
}

variable "regions" {
  description = "List of regions where Cloud IDS should be deployed"
  type        = list(string)
}

variable "zones" {
  description = "Map of regions to zones for Cloud IDS deployment"
  type        = map(string)
}

variable "network_self_links" {
  description = "Map of region to network self link where Cloud IDS will be deployed"
  type        = map(string)
}

variable "subnet_self_links" {
  description = "Map of region to subnet self link where Cloud IDS will be deployed"
  type        = map(string)
}

variable "severity" {
  description = "Severity level for Cloud IDS alerts"
  type        = string
  default     = "INFORMATIONAL"
  validation {
    condition     = contains(["INFORMATIONAL", "LOW", "MEDIUM", "HIGH", "CRITICAL"], var.severity)
    error_message = "Severity must be one of: INFORMATIONAL, LOW, MEDIUM, HIGH, CRITICAL."
  }
}

variable "mirrored_instances" {
  description = "List of instance URLs to mirror traffic from (optional)"
  type        = list(string)
  default     = []
}

variable "ids_instance_name_prefix" {
  description = "Prefix for Cloud IDS instance names"
  type        = string
  default     = "ids"
}

variable "threat_exceptions" {
  description = "List of threat IDs to be excluded from alerting"
  type        = list(string)
  default     = []
}

variable "enable_packet_mirroring" {
  description = "Whether to enable packet mirroring for Cloud IDS"
  type        = bool
  default     = true
}

variable "packet_mirroring_tags" {
  description = "Network tags to use for packet mirroring"
  type        = list(string)
  default     = []
}

variable "packet_mirroring_cidr_ranges" {
  description = "CIDR ranges to use for packet mirroring"
  type        = list(string)
  default     = []
}
