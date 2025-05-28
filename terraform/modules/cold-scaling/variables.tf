variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Prefix for all resources"
  type        = string
}

variable "hot_regions" {
  description = "List of hot regions (always active)"
  type        = list(string)
}

variable "cold_regions" {
  description = "List of cold regions (scale on demand)"
  type        = list(string)
}

variable "load_balancer_name" {
  description = "Name of the Global Load Balancer forwarding rule"
  type        = string
}

variable "function_region" {
  description = "Region to deploy Cloud Function"
  type        = string
  default     = "us-central1"
}

variable "function_source_path" {
  description = "Path to the zipped Cloud Function source code"
  type        = string
  default     = "./functions/cold-cluster-scaler.zip"
}

# Scaling configuration
variable "scaling_thresholds" {
  description = "Thresholds for traffic-based scaling decisions"
  type = object({
    asia_requests_per_10min      = number
    asia_traffic_percentage      = number
    latency_threshold_ms         = number
    min_total_requests           = number
    scale_down_asia_requests     = number
    scale_down_latency_ms        = number
  })
  default = {
    asia_requests_per_10min      = 50
    asia_traffic_percentage      = 10
    latency_threshold_ms         = 500
    min_total_requests           = 100
    scale_down_asia_requests     = 10
    scale_down_latency_ms        = 200
  }
}

# Scheduling configuration
variable "enable_scheduled_scaling" {
  description = "Enable scheduled automatic scaling checks"
  type        = bool
  default     = true
}

variable "scaling_schedule_interval" {
  description = "How often to run scaling checks (in minutes)"
  type        = number
  default     = 5

  validation {
    condition     = var.scaling_schedule_interval >= 1 && var.scaling_schedule_interval <= 60
    error_message = "Scaling schedule interval must be between 1 and 60 minutes."
  }
}

variable "schedule_timezone" {
  description = "Timezone for the scaling schedule"
  type        = string
  default     = "UTC"
}

# Optional features
variable "enable_manual_triggers" {
  description = "Enable Pub/Sub topic for manual scaling triggers"
  type        = bool
  default     = false
}

variable "enable_scaling_logs" {
  description = "Enable detailed logging for scaling operations"
  type        = bool
  default     = true
}