project_id          = "uporto-cd"
project_name        = "uporto-cd"
credentials_file    = "~/terraform-sa.json"
ssh_public_key_path = "/home/eduardo-mdc/.ssh/id_rsa.pub"
admin_username      = "ubuntu"
min_nodes           = 1
max_nodes           = 3
node_machine_type   = "e2-medium" # 2 vCPU, 4GB memory
node_disk_size_gb   = 40
node_disk_type      = "pd-standard"
admin_machine_type  = "e2-standard-2"
regions             = ["europe-west4", "us-south1", "asia-southeast1"]
enable_cdn          = false

# Domain and SSL configuration
domain_name         = "adm-cdn.pt"
enable_regional_subdomains = false  # Set to true if you want europe.yourdomain.com, etc.
enable_caa_records        = true
additional_domains        = []  # Add any additional domains here

# Storage Configuration
environment                    = "production"
master_bucket_location         = "EU"  # EU since primary region is europe-west4
enable_storage_versioning      = true   # Keep versions of uploaded content
enable_regional_storage_versioning = false  # Cache buckets don't need versioning
enable_storage_lifecycle        = false # Manual content management
enable_cache_lifecycle          = false # Don't auto-delete cached content
enable_bucket_notifications     = false # Manual sync for now
storage_public_access_prevention = "enforced"  # Secure by default
storage_force_destroy           = false # Protect against accidental deletion