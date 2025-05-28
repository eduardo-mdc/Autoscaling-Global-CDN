# Cold Cluster Scaling Module
# Deploys traffic-based scaling for cold clusters only

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "cloudscheduler.googleapis.com",
    "storage.googleapis.com"
  ])

  service            = each.value
  disable_on_destroy = false
}

# Storage bucket for Cloud Function source code
resource "google_storage_bucket" "function_source" {
  name     = "${var.project_name}-cold-scaler-source"
  location = var.function_region

  # Lifecycle to clean up old versions
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required_apis]
}

data "archive_file" "function_source" {
  type        = "zip"
  source_dir  = var.function_source_path
  output_path = "${path.module}/functions/cold-autoscaler.zip"
}

# Upload function source code
resource "google_storage_bucket_object" "function_code" {
  name   = "cold-cluster-scaler-${formatdate("YYYY-MM-DD-hhmm", timestamp())}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.function_source.output_path

  lifecycle {
    replace_triggered_by = [data.archive_file.function_source]
  }
}

# Service account for the scaler function
resource "google_service_account" "scaler_sa" {
  account_id   = "${var.project_name}-cold-scaler"
  display_name = "Cold Cluster Scaler Service Account"
  description  = "Service account for traffic-based cold cluster scaling"
}

# IAM permissions for cluster scaling
resource "google_project_iam_member" "scaler_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.scaler_sa.email}"
}

# IAM permissions for monitoring metrics
resource "google_project_iam_member" "scaler_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.scaler_sa.email}"
}

# IAM permissions for logging
resource "google_project_iam_member" "scaler_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.scaler_sa.email}"
}

# Cold cluster scaler Cloud Function
resource "google_cloudfunctions_function" "cold_cluster_scaler" {
  name        = "${var.project_name}-cold-cluster-scaler"
  description = "Scales cold clusters based on geographic traffic patterns"
  runtime     = "python39"

  available_memory_mb   = 512
  timeout              = 300  # 5 minutes
  max_instances        = 1    # Prevent concurrent scaling operations

  source_archive_bucket = google_storage_bucket.function_source.name
  source_archive_object = google_storage_bucket_object.function_code.name
  entry_point          = "scale_cold_cluster"

  trigger_http = true
  https_trigger_security_level = "SECURE_OPTIONAl"

  # Environment variables for scaling logic
  environment_variables = {
    PROJECT_ID                = var.project_id
    HOT_REGIONS              = join(",", var.hot_regions)
    COLD_REGIONS             = join(",", var.cold_regions)
    LOAD_BALANCER_NAME       = var.load_balancer_name
    ASIA_REQUESTS_THRESHOLD  = var.scaling_thresholds.asia_requests_per_10min
    LATENCY_THRESHOLD_MS     = var.scaling_thresholds.latency_threshold_ms
    MIN_TOTAL_REQUESTS       = var.scaling_thresholds.min_total_requests
    SCALE_DOWN_ASIA_REQUESTS = var.scaling_thresholds.scale_down_asia_requests
    SCALE_DOWN_LATENCY_MS    = var.scaling_thresholds.scale_down_latency_ms
  }

  service_account_email = google_service_account.scaler_sa.email

  depends_on = [
    google_project_service.required_apis,
    google_project_iam_member.scaler_container_admin
  ]
}

# Cloud Scheduler job to run scaler automatically
resource "google_cloud_scheduler_job" "scaler_job" {
  count = var.enable_scheduled_scaling ? 1 : 0

  name        = "${var.project_name}-cold-scaler-job"
  description = "Runs cold cluster scaler every ${var.scaling_schedule_interval} minutes"
  schedule    = "*/${var.scaling_schedule_interval} * * * *"
  time_zone   = var.schedule_timezone

  http_target {
    uri         = google_cloudfunctions_function.cold_cluster_scaler.https_trigger_url
    http_method = "POST"

    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      "trigger" = "scheduled"
      "timestamp" = timestamp()
    }))

    oidc_token {
      service_account_email = google_service_account.scaler_sa.email
      audience             = google_cloudfunctions_function.cold_cluster_scaler.https_trigger_url
    }
  }

  retry_config {
    retry_count = 3
  }

  depends_on = [google_project_service.required_apis]
}

# Optional: Pub/Sub topic for manual scaling triggers
resource "google_pubsub_topic" "manual_scaling" {
  count = var.enable_manual_triggers ? 1 : 0

  name = "${var.project_name}-cold-scaling-manual"

  labels = {
    purpose = "cold-cluster-scaling"
    type    = "manual-trigger"
  }
}

# Optional: Pub/Sub subscription for manual scaling
resource "google_pubsub_subscription" "manual_scaling" {
  count = var.enable_manual_triggers ? 1 : 0

  name  = "${var.project_name}-cold-scaling-manual-sub"
  topic = google_pubsub_topic.manual_scaling[0].name

  # Short ack deadline for quick processing
  ack_deadline_seconds = 20

  push_config {
    push_endpoint = google_cloudfunctions_function.cold_cluster_scaler.https_trigger_url

    oidc_token {
      service_account_email = google_service_account.scaler_sa.email
    }
  }
}