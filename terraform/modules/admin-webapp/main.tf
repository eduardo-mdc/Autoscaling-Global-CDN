# Cloud Run Admin Webapp Module
# Deploys the admin webapp as a containerized service

# Enable required APIs
resource "google_project_service" "run_api" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "build_api" {
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# Create service account for Cloud Run
resource "google_service_account" "admin_webapp" {
  account_id   = "${var.project_name}-admin-webapp"
  display_name = "Admin Webapp Service Account"
  description  = "Service account for admin webapp Cloud Run service"
}

# Grant storage permissions to service account
resource "google_project_iam_member" "admin_webapp_storage" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.admin_webapp.email}"
}

resource "google_cloud_run_service" "admin_webapp" {
  name     = "${var.project_name}-admin-webapp"
  location = var.region

  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "all"
    }
  }

  template {
    spec {
      service_account_name = google_service_account.admin_webapp.email

      containers {
        image = var.container_image

        ports {
          container_port = 80
        }

        env {
          name  = "VIDEOS_MOUNT_PATH"
          value = "/app/videos"
        }

        env {
          name  = "GCS_BUCKET_NAME"
          value = var.master_bucket_name
        }

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "PROJECT_NAME"
          value = var.project_name
        }

        env {
          name  = "REGIONS"
          value = join(",", var.regions)
        }

        resources {
          limits = {
            cpu    = "4000m"
            memory = "2096Mi"
          }
        }
      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "0"
        "autoscaling.knative.dev/maxScale" = "3"
        "run.googleapis.com/execution-environment" = "gen2"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [google_project_service.run_api]
}

# Grant specific users access to the Cloud Run service
resource "google_cloud_run_service_iam_member" "admin_webapp_users" {
  for_each = toset(var.admin_iap_members)

  service  = google_cloud_run_service.admin_webapp.name
  location = google_cloud_run_service.admin_webapp.location
  role     = "roles/run.invoker"
  member   = each.value
}

