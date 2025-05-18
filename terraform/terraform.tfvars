project_id          = "uporto-cd"
project_name        = "uporto-cd"
credentials_file    = "~/terraform-sa.json"
ssh_public_key_path = "~/.ssh/id_rsa.pub"
admin_username      = "admin"
min_nodes           = 1
max_nodes           = 3
node_machine_type   = "e2-medium" # 2 vCPU, 4GB memory
node_disk_size_gb   = 40
node_disk_type      = "pd-standard"
admin_machine_type  = "e2-standard-2"
regions             = ["europe-west4", "us-east1", "asia-southeast1"]
enable_cdn          = false

# Uncomment and set domain_name if you want to use a custom domain
# domain_name           = "example.com"