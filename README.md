# Multi-Region Kubernetes Infrastructure on Scaleway

This Terraform configuration sets up a multi-region Kubernetes infrastructure on Scaleway with an admin server that has access to all VPCs.

## Architecture

The infrastructure consists of:

1. **Network Resources in Three Regions**:
    - VPCs in Paris (fr-par), Amsterdam (nl-ams), and Warsaw (pl-waw)
    - Private networks in each region
    - Security groups for web traffic and Kubernetes clusters

2. **Kubernetes Clusters in Each Region**:
    - Kapsule Kubernetes clusters with Cilium CNI
    - Autoscaling node pools
    - Security groups for controlled access

3. **Admin Server**:
    - Centralized management server in Paris region
    - Access to all private networks via VPC gateways
    - Pre-installed tools for Kubernetes and infrastructure management
    - Kubeconfigs for all clusters

## Isolation Requirements

- VMs/containers in different zones do not communicate with each other
- Only the admin server can reach all nodes in the network
- Nodes cannot access the admin server (one-way access)

## Module Structure

```
.
├── main.tf                # Root module configuration
├── variables.tf           # Root variables
├── outputs.tf             # Root outputs
├── providers.tf           # Provider configuration for all regions
└── modules/
    ├── network/           # Network module for VPC and security groups
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── k8s_cluster/       # Kubernetes cluster module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── admin/             # Admin server module
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── cloud-init.yml # Cloud-init configuration for admin server
```

## Prerequisites

To deploy this infrastructure, you need:

1. Scaleway account with API credentials
2. Terraform installed locally (version >= 1.0.0)
3. SSH key pair for admin server access

## Deployment

1. Clone this repository
2. Create a `terraform.tfvars` file with your configuration:

```hcl
scw_access_key      = "your-scaleway-access-key"
scw_secret_key      = "your-scaleway-secret-key"
scw_organization_id = "your-organization-id"
scw_project_id      = "your-project-id"
ssh_public_key      = "ssh-rsa AAA..."
ssh_private_key_path = "/path/to/your/private/key"
admin_allowed_ip    = "your-ip-address/32"  # Restrict to your IP
```

3. Initialize Terraform:

```bash
terraform init
```

4. Apply the configuration:

```bash
terraform apply
```

## Post-Deployment

After deployment:

1. SSH to the admin server using the public IP displayed in the outputs:

```bash
ssh admin@$(terraform output -raw admin_server_public_ip)
```

2. Use kubectl to interact with all clusters:

```bash
# List all contexts
kubectl config get-contexts

# Switch to Paris cluster
kubectl config use-context paris

# Switch to Amsterdam cluster
kubectl config use-context amsterdam

# Switch to Warsaw cluster
kubectl config use-context warsaw
```

## Ansible Configuration

For additional server configuration, use Ansible with the admin server as the control node:

1. Create an inventory file on the admin server
2. Create playbooks for specific configurations
3. Use the pre-installed Ansible to apply configurations

## Security Notes

- Update `admin_allowed_ip` to restrict admin server access to your IP address
- Consider using a bastion host pattern for additional security
- Implement additional security groups as needed
- Set up proper Kubernetes RBAC for cluster access

## Future Improvements

- Add monitoring and logging infrastructure
- Implement CI/CD pipelines for application deployment
- Configure cluster federation or multi-cluster management tools
- Set up backup and recovery procedures