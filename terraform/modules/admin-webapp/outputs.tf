output "service_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_service.admin_webapp.status[0].url
}

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_service.admin_webapp.name
}

output "service_account_email" {
  description = "Email of the service account used by Cloud Run"
  value       = google_service_account.admin_webapp.email
}
