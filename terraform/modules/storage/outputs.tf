# terraform/modules/storage/outputs.tf
# Outputs for the storage module

# Master bucket information
output "master_bucket_name" {
  description = "Name of the master content bucket"
  value       = google_storage_bucket.master.name
}

output "master_bucket_url" {
  description = "URL of the master content bucket"
  value       = google_storage_bucket.master.url
}

output "master_bucket_location" {
  description = "Location of the master content bucket"
  value       = google_storage_bucket.master.location
}

# Regional cache buckets information
output "regional_bucket_names" {
  description = "Map of region to regional cache bucket names"
  value = {
    for region in var.regions :
    region => google_storage_bucket.regional_cache[region].name
  }
}

output "regional_bucket_urls" {
  description = "Map of region to regional cache bucket URLs"
  value = {
    for region in var.regions :
    region => google_storage_bucket.regional_cache[region].url
  }
}

output "regional_bucket_locations" {
  description = "Map of region to regional cache bucket locations"
  value = {
    for region in var.regions :
    region => google_storage_bucket.regional_cache[region].location
  }
}

# Service account information
output "content_admin_sa_email" {
  description = "Email of the content admin service account"
  value       = google_service_account.content_admin.email
}

output "content_reader_sa_email" {
  description = "Email of the content reader service account"
  value       = google_service_account.content_reader.email
}

output "content_admin_sa_key" {
  description = "Private key for content admin service account (base64 encoded)"
  value       = google_service_account_key.content_admin_key.private_key
  sensitive   = true
}

output "content_reader_sa_key" {
  description = "Private key for content reader service account (base64 encoded)"
  value       = google_service_account_key.content_reader_key.private_key
  sensitive   = true
}

# Bucket access commands for reference
output "gsutil_sync_commands" {
  description = "Example gsutil commands for content synchronization"
  value = {
    upload_to_master = "gsutil -m rsync -r -d /opt/content/uploads/ gs://${google_storage_bucket.master.name}/"
    sync_to_regional = {
      for region in var.regions :
      region => "gsutil -m rsync -r -d gs://${google_storage_bucket.master.name}/ gs://${google_storage_bucket.regional_cache[region].name}/"
    }
  }
}

# Kubernetes annotations for Workload Identity
output "workload_identity_annotation" {
  description = "Annotation to add to Kubernetes service account for Workload Identity"
  value       = "iam.gke.io/gcp-service-account=${google_service_account.content_reader.email}"
}

# CSI driver configuration
output "csi_driver_config" {
  description = "Configuration for GCS FUSE CSI driver per region"
  value = {
    for region in var.regions :
    region => {
      bucket_name        = google_storage_bucket.regional_cache[region].name
      service_account    = google_service_account.content_reader.email
      mount_path         = "/mnt/videos"
      volume_name        = "content-storage-${region}"
      storage_class_name = "gcs-fuse-csi-${region}"
    }
  }
}

# Pub/Sub topic information (if enabled)
output "content_sync_topic" {
  description = "Pub/Sub topic for content sync notifications"
  value       = var.enable_bucket_notifications ? google_pubsub_topic.content_sync[0].name : null
}

# Storage summary for documentation
output "storage_summary" {
  description = "Summary of all storage resources created"
  value = {
    master_bucket = {
      name     = google_storage_bucket.master.name
      location = google_storage_bucket.master.location
      purpose  = "Content ingestion and master storage"
    }
    regional_buckets = {
      for region in var.regions :
      region => {
        name     = google_storage_bucket.regional_cache[region].name
        location = google_storage_bucket.regional_cache[region].location
        purpose  = "Regional content cache for ${region}"
      }
    }
    service_accounts = {
      admin = {
        email   = google_service_account.content_admin.email
        purpose = "Admin VM content management"
      }
      reader = {
        email   = google_service_account.content_reader.email
        purpose = "Kubernetes pod content access"
      }
    }
  }
}