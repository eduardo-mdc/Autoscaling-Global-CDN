# Multi-Region GKE Streaming Server Infrastructure

A modular Terraform and Ansible-based infrastructure for deploying a custom streaming server across multiple Google Cloud regions with global load balancing.

## Architecture Overview

This project deploys:
- **Admin VM**: Centralized management node with access to all GKE clusters
- **Regional VPCs**: Isolated networks in each deployment region
- **GKE Clusters**: Private Kubernetes clusters in each region
- **Bastion Hosts**: Private jump hosts for accessing regional clusters
- **Global Load Balancer**: HTTP(S) load balancer for global traffic distribution
- **Custom Streaming Server**: HLS-capable streaming application deployed as DaemonSet

## Prerequisites

### Required Tools
- [Terraform](https://www.terraform.io/downloads.html) >= 0.14
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) >= 2.9
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

### Google Cloud Setup

1. **Create a GCP Project**
   ```bash
   gcloud projects create YOUR-PROJECT-ID
   gcloud config set project YOUR-PROJECT-ID
   ```

2. **Enable Required APIs**
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable container.googleapis.com
   gcloud services enable dns.googleapis.com
   ```

3. **Create Service Account for Terraform**
   ```bash
   # Create service account
   gcloud iam service-accounts create terraform-sa \
     --display-name="Terraform Service Account"
   
   # Grant necessary permissions
   gcloud projects add-iam-policy-binding YOUR-PROJECT-ID \
     --member="serviceAccount:terraform-sa@YOUR-PROJECT-ID.iam.gserviceaccount.com" \
     --role="roles/compute.admin"
   
   gcloud projects add-iam-policy-binding YOUR-PROJECT-ID \
     --member="serviceAccount:terraform-sa@YOUR-PROJECT-ID.iam.gserviceaccount.com" \
     --role="roles/container.admin"
   
   gcloud projects add-iam-policy-binding YOUR-PROJECT-ID \
     --member="serviceAccount:terraform-sa@YOUR-PROJECT-ID.iam.gserviceaccount.com" \
     --role="roles/dns.admin"
   
   gcloud projects add-iam-policy-binding YOUR-PROJECT-ID \
     --member="serviceAccount:terraform-sa@YOUR-PROJECT-ID.iam.gserviceaccount.com" \
     --role="roles/iam.serviceAccountUser"
   
   # Create and download key
   gcloud iam service-accounts keys create ~/terraform-sa.json \
     --iam-account=terraform-sa@YOUR-PROJECT-ID.iam.gserviceaccount.com
   ```

4. **Generate SSH Keys**
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
   ```

## Configuration

### 1. Terraform Variables

Edit `terraform/terraform.tfvars` with your specific configuration:

```hcl
# Required - Must be customized
project_id          = "your-project-id"
project_name        = "your-project-name"
credentials_file    = "~/terraform-sa.json"  # Path to service account key
ssh_public_key_path = "/home/YOUR-USER/.ssh/id_rsa.pub"  # Your SSH public key
admin_username      = "ubuntu"  # Or your preferred admin username

# Optional - Can be customized
regions             = ["europe-west4", "us-south1", "asia-southeast1"]
min_nodes           = 1
max_nodes           = 3
node_machine_type   = "e2-medium"
node_disk_size_gb   = 40
admin_machine_type  = "e2-standard-2"
enable_cdn          = false

# Uncomment for custom domain
# domain_name       = "yourdomain.com"
```

### 2. Streaming Server Configuration

Edit `playbooks/roles/streaming-server/defaults/main.yml`:

```yaml
# Docker image configuration - UPDATE THESE
docker_hub_image: "your-dockerhub-username/your-streaming-server"
docker_hub_tag: "latest"

# Application configuration
app_name: "streaming-server"
app_namespace: "streaming"
app_http_port: 80
app_https_port: 443
```

## Deployment

### Phase 1: Infrastructure Deployment

Deploy the infrastructure using the automated script:

```bash
# Make sure you're in the project root
cd multi-region-gke-streaming

# Deploy infrastructure
./deploy.sh --apply

# Or destroy infrastructure when needed
./deploy.sh --destroy
```

The script will:
1. Validate prerequisites
2. Initialize and apply Terraform configuration
3. Create admin VM and regional infrastructure
4. Generate Ansible inventory and variables
5. Set up jump host configuration for bastion access

### Phase 2: Kubernetes Setup

Navigate to the playbooks directory and run Ansible playbooks:

```bash
cd playbooks

# Option 1: Run specific phases with tags
ansible-playbook streaming-deployment.yaml --tags "phase1"  # Setup admin and bastion hosts
ansible-playbook streaming-deployment.yaml --tags "phase2"  # Deploy namespaces
ansible-playbook streaming-deployment.yaml --tags "phase3"  # Deploy ConfigMaps
ansible-playbook streaming-deployment.yaml --tags "phase4"  # Deploy streaming DaemonSet
ansible-playbook streaming-deployment.yaml --tags "phase5"  # Deploy services

# Option 2: Run all phases at once
ansible-playbook streaming-deployment.yaml

# Option 3: Run specific components
ansible-playbook streaming-deployment.yaml --tags "setup"     # Initial setup only
ansible-playbook streaming-deployment.yaml --tags "streaming" # Streaming components only
ansible-playbook streaming-deployment.yaml --tags "verify"    # Verification only
```

### Phase 3: Application Deployment

The streaming server is deployed automatically in Phase 2, but you can also deploy additional applications:

```bash
# Deploy monitoring stack (optional)
ansible-playbook streaming-deployment.yaml --tags "monitoring"

# Deploy ingress controllers (optional)  
ansible-playbook streaming-deployment.yaml --tags "ingress"
```

## Hardcoded Values That Must Be Customized

### Critical - Must Change
- **`terraform/terraform.tfvars`**:
   - `project_id`: Your GCP project ID
   - `ssh_public_key_path`: Path to your SSH public key
   - `credentials_file`: Path to service account JSON (default: `~/terraform-sa.json`)

### Docker Image - Must Change
- **`playbooks/roles/streaming-server/defaults/main.yml`**:
   - `docker_hub_image`: Your streaming server Docker image
   - `docker_hub_tag`: Your image tag

### Optional Customizations
- **Regions**: Default regions are `europe-west4`, `us-south1`, `asia-southeast1`
- **Machine Types**: Default uses `e2-medium` for nodes, `e2-standard-2` for admin
- **Admin Username**: Default is `ubuntu`
- **Resource Limits**: CPU/memory limits for the streaming application
- **SSL Configuration**: Self-signed certificates are used by default

## Project Structure

```
.
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                  # Main configuration
│   ├── variables.tf             # Variable definitions
│   ├── terraform.tfvars         # Configuration values (customize this)
│   └── modules/
│       ├── admin/               # Admin VM module
│       ├── network/             # VPC networks module
│       ├── gke/                 # GKE clusters module
│       ├── bastion/             # Bastion hosts module
│       └── loadbalancer/        # Global load balancer module
│
├── playbooks/                   # Ansible configuration
│   ├── streaming-deployment.yaml # Main deployment playbook
│   ├── inventory/               # Auto-generated inventory
│   ├── group_vars/              # Auto-generated variables
│   └── roles/
│       ├── common/              # Basic server setup
│       ├── gcloud/              # Google Cloud SDK setup
│       ├── bastion/             # Bastion host configuration
│       └── streaming-server/    # Streaming application deployment
│
├── deploy.sh                    # Main deployment script
└── generate-ansible-vars.sh     # Terraform output to Ansible vars
```

## Network Architecture

- **Admin VPC**: `10.250.0.0/24` - Centralized management network
- **Regional VPCs**: `10.{N}.0.0/20` - Isolated regional networks (N = region number)
- **GKE Master Networks**: `172.16.{N}.0/28` - Private cluster control planes
- **Pod Networks**: `10.{100+N}.0.0/16` - Kubernetes pod networks
- **Service Networks**: `10.{200+N}.0.0/16` - Kubernetes service networks

## Access Patterns

1. **Admin Access**: SSH directly to admin VM (public IP)
2. **Regional Access**: SSH to bastions via admin VM as jump host
3. **Kubernetes Access**: kubectl from bastions to regional clusters
4. **Application Access**: Through global load balancer

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   ```bash
   # Check if admin VM is running
   gcloud compute instances list --filter="name~admin"
   
   # Verify SSH key in metadata
   gcloud compute instances describe ADMIN-VM-NAME --zone=ZONE
   ```

2. **Terraform Apply Failed**
   ```bash
   # Check API enablement
   gcloud services list --enabled
   
   # Verify service account permissions
   gcloud projects get-iam-policy YOUR-PROJECT-ID
   ```

3. **Ansible Connection Failed**
   ```bash
   # Test connectivity
   ansible admin -m ping
   
   # Check inventory file
   cat playbooks/inventory/hosts.ini
   ```

4. **GKE Access Issues**
   ```bash
   # From bastion host, test cluster connectivity
   /opt/scripts/connect-to-local-cluster.sh
   
   # Check authorized networks
   gcloud container clusters describe CLUSTER-NAME --region=REGION
   ```

### Debug Commands

```bash
# Check infrastructure status
cd terraform && terraform show

# Test Ansible connectivity
cd playbooks && ansible all -m ping

# Check streaming server status
kubectl -n streaming get pods -o wide
kubectl -n streaming get services
kubectl -n streaming get daemonset

# View streaming server logs
kubectl -n streaming logs -l app=streaming-server
```

## Security Considerations

- All GKE clusters use private nodes and private endpoints
- Admin VM is the only instance with public IP
- Inter-region traffic is blocked by firewall rules
- Service account follows principle of least privilege
- Self-signed certificates are used by default (replace for production)

## Maintenance

### Updating Infrastructure
```bash
# Update Terraform configuration
cd terraform
terraform plan
terraform apply
```

### Updating Application
```bash
# Update variables and redeploy
cd playbooks
ansible-playbook streaming-deployment.yaml --tags "streaming"
```

### Scaling
```bash
# Update node counts in terraform.tfvars
# Then run terraform apply
```

## Cost Optimization

- Uses `e2-medium` instances by default (2 vCPU, 4GB RAM)
- Node pools with autoscaling (min: 1, max: 3)
- `pd-standard` disks for cost efficiency
- Can be customized in `terraform.tfvars`

## Support

For issues with this infrastructure:
1. Check the troubleshooting section
2. Review Terraform and Ansible logs
3. Verify all prerequisites are met
4. Ensure all hardcoded values are properly customized