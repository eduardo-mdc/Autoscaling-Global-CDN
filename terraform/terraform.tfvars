project_id          = "uporto-cd"
project_name        = "uporto-cd"
credentials_file    = "~/terraform-sa.json"
ssh_public_key_path = "/home/eduardo-mdc/.ssh/id_rsa.pub"
admin_username      = "ubuntu"
min_nodes           = 1
max_nodes           = 3
node_machine_type   = "e2-standard-2"  # 2 dedicated vCPU, 7.5GB RAM
node_disk_size_gb   = 40
node_disk_type      = "pd-standard"
admin_machine_type  = "e2-standard-2"
regions             = ["europe-west2", "us-south1", "asia-southeast1"]
enable_cdn          = false

zones = {
  "europe-west2"    = "europe-west2-a",
  "us-south1"       = "us-south1-a",
  "asia-southeast1" = "asia-southeast1-a"
}

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
storage_force_destroy           = true # False -> Protect against accidental deletion

# IAM Configuration
admin_iap_members = ["user:eduardo.mmd.correia@gmail.com","user:alfilipe.it@gmail.com"]
oauth_client_id = "313506890289-306orl15c02jl7henbtc5c7ln094b0fa.apps.googleusercontent.com"
oauth_client_secret = "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"


# HOT/COLD CLUSTER CONFIGURATION
# Hot regions (always active, high traffic)
hot_regions = ["europe-west2", "us-south1"]  # EU and Americas

# Cold regions (scaled down, activated on demand)
cold_regions = ["asia-southeast1"]  # APAC

# Hot cluster configuration - always running, high performance
hot_cluster_config = {
  min_nodes         = 2             # Always have 2 nodes minimum
  max_nodes         = 3              # Scale up to 3 nodes
  initial_nodes     = 1              # Start with 3 nodes
  machine_type      = "e2-standard-2" # More powerful (4 vCPU, 16GB RAM)
  disk_size_gb      = 50            # Larger disk for caching
  disk_type         = "pd-standard"       # SSD for performance
}

# Cold cluster configuration - cost-optimized, scale-to-zero
cold_cluster_config = {
  min_nodes         = 0              # Can scale to zero
  max_nodes         = 2              # Moderate scale capacity
  initial_nodes     = 0              # Start with 0 nodes (scaled down)
  machine_type      = "e2-standard-2" # Standard size (2 vCPU, 8GB RAM)
  disk_size_gb      = 50             # Smaller disk for cost
  disk_type         = "pd-standard"  # Standard disk for cost
}

# Auto-scaling configuration
enable_cluster_autoscaling = true
cold_cluster_scale_up_trigger = "geographic_traffic"

# Traffic-based scaling thresholds
scale_up_thresholds = {
  asia_requests_per_10min      = 50   # Scale up if >50 requests from Asia in 10min
  asia_traffic_percentage      = 10   # Scale up if >10% of traffic from Asia
  latency_threshold_ms         = 500  # Scale up if latency to hot clusters >500ms
  min_total_requests           = 100  # Need minimum 100 total requests to consider scaling
  scale_down_asia_requests     = 10   # Scale down if <10 Asia requests
  scale_down_latency_ms        = 200  # Scale down if latency <200ms
}

# Domain and SSL configuration
domain_name         = "adm-cdn.pt"
enable_regional_subdomains = false
enable_caa_records        = true
additional_domains        = []

# Storage Configuration
environment                    = "production"
master_bucket_location         = "EU"
enable_storage_versioning      = true
enable_regional_storage_versioning = false
enable_storage_lifecycle        = false
enable_cache_lifecycle          = false
enable_bucket_notifications     = false
storage_public_access_prevention = "enforced"
storage_force_destroy           = true

# Security Configuration
admin_allowed_ips = ["0.0.0.0/0"]  # Restrict this to your IP range
admin_iap_members = ["user:eduardo.mmd.correia@gmail.com","user:alfilipe.it@gmail.com"]
oauth_client_id = "313506890289-306orl15c02jl7henbtc5c7ln094b0fa.apps.googleusercontent.com"
oauth_client_secret = "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"