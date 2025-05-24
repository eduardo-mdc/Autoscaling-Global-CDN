variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "project_name" {
  description = "The name of the project, used for naming resources"
  type        = string
}

variable "regions" {
  description = "List of regions where monitoring should be deployed"
  type        = list(string)
}

variable "zones" {
  description = "Map of regions to zones for monitoring deployment"
  type        = map(string)
}

variable "dashboard_display_name" {
  description = "Display name for the monitoring dashboard"
  type        = string
  default     = "Global Load Balancer Monitoring"
}

variable "load_balancer_name" {
  description = "Name of the load balancer to monitor"
  type        = string
}

variable "backend_service_names" {
  description = "List of backend service names to monitor"
  type        = list(string)
  default     = []
}

variable "enable_latency_monitoring" {
  description = "Enable latency monitoring for the load balancer"
  type        = bool
  default     = true
}

variable "enable_request_count_monitoring" {
  description = "Enable request count monitoring for the load balancer"
  type        = bool
  default     = true
}

variable "enable_backend_health_monitoring" {
  description = "Enable backend health monitoring for the load balancer"
  type        = bool
  default     = true
}

variable "dashboard_refresh_rate" {
  description = "Dashboard refresh rate in seconds"
  type        = number
  default     = 300
}

variable "alert_notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
}

variable "latency_threshold_ms" {
  description = "Threshold for latency alerts in milliseconds"
  type        = number
  default     = 1000
}

variable "error_rate_threshold_percent" {
  description = "Threshold for error rate alerts in percentage"
  type        = number
  default     = 5
}

variable "backend_health_threshold_percent" {
  description = "Threshold for backend health alerts in percentage"
  type        = number
  default     = 80
}
