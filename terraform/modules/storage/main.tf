# terraform/modules/storage/main.tf
# Storage module for content distribution with master and regional cache buckets

# Enable required APIs
resource "google_project_service" "storage_api" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam_api" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

# Master bucket for content ingestion (multi-regional for high availability)
resource "google_storage_bucket" "master" {
  name     = "${var.project_name}-content-master"
  location = var.master_bucket_location

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Versioning for content management
  versioning {
    enabled = var.enable_versioning
  }

  # Lifecycle management
  dynamic "lifecycle_rule" {
    for_each = var.enable_lifecycle_management ? [1] : []
    content {
      condition {
        age = var.lifecycle_delete_age_days
      }
      action {
        type = "Delete"
      }
    }
  }

  # CORS configuration for web access
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "OPTIONS"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  # Labels for organization
  labels = {
    environment = var.environment
    purpose     = "content-master"
    managed-by  = "terraform"
  }

  depends_on = [google_project_service.storage_api]
}

# Regional cache buckets (one per deployment region)
resource "google_storage_bucket" "regional_cache" {
  for_each = toset(var.regions)

  name     = "${var.project_name}-content-${each.value}"
  location = upper(each.value)

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Versioning (usually disabled for cache buckets)
  versioning {
    enabled = var.enable_regional_versioning
  }

  # Lifecycle management for cache buckets
  dynamic "lifecycle_rule" {
    for_each = var.enable_cache_lifecycle_management ? [1] : []
    content {
      condition {
        age = var.cache_lifecycle_delete_age_days
      }
      action {
        type = "Delete"
      }
    }
  }

  # CORS configuration for web access
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "OPTIONS"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  # Labels for organization
  labels = {
    environment = var.environment
    purpose     = "content-cache"
    region      = each.value
    managed-by  = "terraform"
  }

  depends_on = [google_project_service.storage_api]
}

# Create notifications for content sync (optional - can be used later)
resource "google_storage_notification" "master_bucket_notification" {
  count = var.enable_bucket_notifications ? 1 : 0

  bucket         = google_storage_bucket.master.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.content_sync[0].id
  event_types = [
    "OBJECT_FINALIZE",
    "OBJECT_DELETE"
  ]

  depends_on = [google_pubsub_topic_iam_member.publisher]
}

# Pub/Sub topic for content sync notifications (optional)
resource "google_pubsub_topic" "content_sync" {
  count = var.enable_bucket_notifications ? 1 : 0
  name  = "${var.project_name}-content-sync"

  labels = {
    environment = var.environment
    purpose     = "content-sync"
    managed-by  = "terraform"
  }
}

# IAM member for Cloud Storage to publish to Pub/Sub
resource "google_pubsub_topic_iam_member" "publisher" {
  count = var.enable_bucket_notifications ? 1 : 0

  topic  = google_pubsub_topic.content_sync[0].name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${data.google_storage_project_service_account.default.email_address}"
}

# Get the Cloud Storage service account for Pub/Sub permissions
data "google_storage_project_service_account" "default" {
  depends_on = [google_project_service.storage_api]
}