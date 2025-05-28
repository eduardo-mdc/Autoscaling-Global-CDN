# terraform/modules/storage/iam.tf
# IAM configuration for storage access

# Service account for admin VM to manage content
resource "google_service_account" "content_admin" {
  account_id   = "${var.project_name}-content-admin"
  display_name = "Content Administration Service Account"
  description  = "Service account for admin VM to upload and sync content"
}

# Service account key for admin VM
resource "google_service_account_key" "content_admin_key" {
  service_account_id = google_service_account.content_admin.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Service account for Kubernetes pods to read content
resource "google_service_account" "content_reader" {
  account_id   = "${var.project_name}-content-reader"
  display_name = "Content Reader Service Account"
  description  = "Service account for Kubernetes pods to read content from regional buckets"
}

# Service account key for Kubernetes pods
resource "google_service_account_key" "content_reader_key" {
  service_account_id = google_service_account.content_reader.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# IAM binding for admin service account on master bucket (full access)
resource "google_storage_bucket_iam_member" "admin_master_bucket" {
  bucket = google_storage_bucket.master.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.content_admin.email}"
}

# IAM binding for admin service account on regional buckets (full access for sync)
resource "google_storage_bucket_iam_member" "admin_regional_buckets" {
  for_each = toset(var.regions)

  bucket = google_storage_bucket.regional_cache[each.value].name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.content_admin.email}"
}

# IAM binding for pod service account on regional buckets (read-only)
resource "google_storage_bucket_iam_member" "pods_regional_buckets" {
  for_each = toset(var.regions)

  bucket = google_storage_bucket.regional_cache[each.value].name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.content_reader.email}"
}



resource "google_service_account_iam_member" "workload_identity_binding" {
  for_each = toset(var.regions)

  service_account_id = google_service_account.content_reader.name
  role               = "roles/iam.workloadIdentityUser"

  # Bind to streaming namespace in each region
  member = "serviceAccount:${var.project_id}.svc.id.goog[streaming/streaming-server-sa]"
}



# Grant storage object admin role to admin service account for cross-bucket operations
resource "google_project_iam_member" "admin_storage_object_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.content_admin.email}"
}

# Grant storage object viewer role to content reader for cross-bucket operations
resource "google_project_iam_member" "reader_storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.content_reader.email}"
}

# Optional: Create a custom role for more granular permissions
resource "google_project_iam_custom_role" "content_sync" {
  role_id     = "${replace(var.project_name, "-", "_")}_content_sync"
  title       = "Content Sync Role"
  description = "Custom role for content synchronization between buckets"

  permissions = [
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.get",
    "storage.objects.list",
    "storage.buckets.get",
    "storage.buckets.list"
  ]
}

# Bind the custom role to admin service account
resource "google_project_iam_member" "admin_custom_role" {
  project = var.project_id
  role    = google_project_iam_custom_role.content_sync.name
  member  = "serviceAccount:${google_service_account.content_admin.email}"
}