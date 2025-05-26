output "dashboard_url" {
  description = "URL to access the created monitoring dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.lb_dashboard.id}?project=${var.project_id}"
}

output "dashboard_name" {
  description = "Name of the created monitoring dashboard"
  value       = var.dashboard_display_name
}

output "dashboard_id" {
  description = "ID of the created monitoring dashboard"
  value       = google_monitoring_dashboard.lb_dashboard.id
}

output "latency_alert_policy_id" {
  description = "ID of the latency alert policy"
  value       = var.enable_latency_monitoring ? google_monitoring_alert_policy.latency_alert[0].id : null
}

output "error_rate_alert_policy_id" {
  description = "ID of the error rate alert policy"
  value       = var.enable_request_count_monitoring ? google_monitoring_alert_policy.error_rate_alert[0].id : null
}

output "backend_health_metric_descriptor" {
  description = "Metric descriptor for backend health monitoring"
  value       = var.enable_backend_health_monitoring ? google_monitoring_metric_descriptor.backend_health[0].type : null
}

output "monitored_regions" {
  description = "List of regions being monitored"
  value       = var.regions
}

output "monitored_load_balancer" {
  description = "Name of the load balancer being monitored"
  value       = var.load_balancer_name
}

output "monitored_backend_services" {
  description = "List of backend services being monitored"
  value       = var.backend_service_names
}
