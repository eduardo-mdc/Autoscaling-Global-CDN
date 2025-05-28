output "scaler_function_name" {
  description = "Name of the cold cluster scaler Cloud Function"
  value       = google_cloudfunctions_function.cold_cluster_scaler.name
}

output "scaler_function_url" {
  description = "HTTP trigger URL for the scaler function"
  value       = google_cloudfunctions_function.cold_cluster_scaler.https_trigger_url
}

output "scaler_service_account" {
  description = "Email of the scaler service account"
  value       = google_service_account.scaler_sa.email
}

output "scheduler_job_name" {
  description = "Name of the Cloud Scheduler job (if enabled)"
  value       = var.enable_scheduled_scaling ? google_cloud_scheduler_job.scaler_job[0].name : null
}

output "manual_scaling_topic" {
  description = "Pub/Sub topic for manual scaling triggers (if enabled)"
  value       = var.enable_manual_triggers ? google_pubsub_topic.manual_scaling[0].name : null
}

output "scaling_configuration" {
  description = "Summary of scaling configuration"
  value = {
    cold_regions                 = var.cold_regions
    hot_regions                 = var.hot_regions
    asia_requests_threshold     = var.scaling_thresholds.asia_requests_per_10min
    latency_threshold_ms        = var.scaling_thresholds.latency_threshold_ms
    scheduled_scaling_enabled   = var.enable_scheduled_scaling
    schedule_interval_minutes   = var.scaling_schedule_interval
  }
}

locals {
  scale_up_message = jsonencode({
    action = "scale_up"
    region = "asia-southeast1"
  })
}

output "manual_scaling_commands" {
  value = {
    trigger_scale_up = var.enable_manual_triggers ? "gcloud pubsub topics publish ${google_pubsub_topic.manual_scaling[0].name} --message='${local.scale_up_message}'" : ""
  }
}