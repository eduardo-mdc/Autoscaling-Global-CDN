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