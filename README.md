# Multi-Region GKE Streaming Server Infrastructure

## Overview

This project provides a modular infrastructure for deploying a streaming server across multiple GKE clusters with global load balancing. It uses Terraform for infrastructure provisioning and Ansible for configuration management, following a phased deployment approach.

## Key Components

1. **Terraform Infrastructure Modules:**
   - `admin`: Admin VM for secure cluster management
   - `network`: Regional VPC networks and isolation
   - `gke`: Regional Kubernetes clusters
   - `loadbalancer`: Global HTTP load balancer

2. **Ansible Roles:**
   - `common`: Basic server configuration
   - `docker`: Docker installation and configuration
   - `gcloud`: Google Cloud SDK and kubectl setup
   - `k8s-app`: Kubernetes application deployment

3. **Deployment Phases:**
   - Phase 1: Infrastructure provisioning with Terraform
   - Phase 2: Admin VM configuration with Ansible
   - Phase 3: Kubernetes application deployment

## Project Structure

```
/
├── terraform/                # Infrastructure as Code
│   ├── main.tf, variables.tf, etc.
│   └── modules/
│       ├── admin/
│       ├── network/
│       ├── gke/
│       └── loadbalancer/
│
├── playbooks/                # Ansible configuration
│   ├── ansible.cfg
│   ├── inventory/
│   ├── group_vars/
│   ├── site.yml, admin.yml, k8s.yml
│   └── roles/
│       ├── common/
│       ├── docker/
│       ├── gcloud/
│       └── k8s-app/
│
└── deploy.sh                 # Deployment orchestration script
```

## Key Changes from Original

1. **Admin VM Simplification:**
   - Removed complex startup script
   - Using metadata for SSH keys
   - Minimal startup requirements for Ansible integration

2. **Ansible Integration:**
   - Standard role-based Ansible structure
   - Clear separation of responsibilities
   - Modular configuration approach

3. **Deployment Process:**
   - Automated phased deployment
   - Clear dependency management
   - Streamlined configuration

## Usage

```bash
./deploy.sh
```

The deployment script will:
1. Validate prerequisites
2. Prompt for configuration values
3. Deploy infrastructure with Terraform
4. Configure the admin VM with Ansible
5. Deploy the streaming server application to all GKE clusters

## Troubleshooting

**Terraform Deployment Issues:**
If Terraform deployment fails, check:
- GCP credentials
- Project permissions
- API enablement

**SSH Connection Issues:**
If SSH connection fails, check:
- Firewall rules
- SSH key configuration
- Network connectivity

**Ansible Configuration Issues:**
If Ansible configuration fails, check:
- Python installation on target
- Ansible inventory configuration
- Role dependencies

**Kubernetes Deployment Issues:**
If Kubernetes deployment fails, check:
- GKE cluster status
- kubectl configuration
- Docker image accessibility

## Maintenance

For ongoing maintenance:

1. **Infrastructure Updates:**
   ```bash
   cd terraform
   terraform apply
   ```

2. **Configuration Updates:**
   ```bash
   cd playbooks
   ansible-playbook admin.yml
   ```

3. **Application Updates:**
   ```bash
   cd playbooks
   ansible-playbook k8s.yml -e "docker_hub_image=new_image" -e "docker_hub_tag=new_tag"
   ```