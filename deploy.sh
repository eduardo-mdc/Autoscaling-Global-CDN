#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR=$(pwd)
PLAYBOOKS_DIR="${PROJECT_DIR}/playbooks"
TERRAFORM_DIR="${PROJECT_DIR}/terraform"
SSH_PRIVATE_KEY="$HOME/.ssh/id_rsa"
SSH_PUBLIC_KEY="$HOME/.ssh/id_rsa.pub"

# Ensure the script is run from the project root
if [ ! -d "${TERRAFORM_DIR}" ] || [ ! -d "${PLAYBOOKS_DIR}" ]; then
  echo -e "${RED}Error: Please run this script from the project root directory${NC}"
  exit 1
fi

# Display header
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN} Multi-Region GKE Streaming Server ${NC}"
echo -e "${GREEN}====================================${NC}"
echo

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
  echo -e "${RED}Error: terraform is not installed${NC}"
  exit 1
fi

# Check if ansible is installed
if ! command -v ansible &> /dev/null; then
  echo -e "${RED}Error: ansible is not installed${NC}"
  exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}Error: kubectl is not installed${NC}"
  exit 1
fi

# Check if SSH keys exist
if [ ! -f "$SSH_PRIVATE_KEY" ] || [ ! -f "$SSH_PUBLIC_KEY" ]; then
  echo -e "${RED}Error: SSH keys not found at $SSH_PRIVATE_KEY and $SSH_PUBLIC_KEY${NC}"
  exit 1
fi

echo -e "${GREEN}All prerequisites are met.${NC}"
echo

# Read configuration
echo -e "${YELLOW}Please enter the following configuration:${NC}"
read -p "GCP Project ID: " PROJECT_ID
read -p "Project Name (prefix for resources): " PROJECT_NAME
read -p "Docker Hub Image (e.g., username/image): " DOCKER_HUB_IMAGE
read -p "Docker Hub Tag (e.g., latest): " DOCKER_HUB_TAG
read -p "Admin Username (default: admin): " ADMIN_USERNAME
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}

# Export variables for Terraform
export TF_VAR_project_id="$PROJECT_ID"
export TF_VAR_project_name="$PROJECT_NAME"
export TF_VAR_admin_username="$ADMIN_USERNAME"
export TF_VAR_ssh_public_key_path="$SSH_PUBLIC_KEY"

# Export variables for Ansible
export ANSIBLE_REGIONS="${TF_VAR_regions:-europe-west4,us-east1,asia-southeast1}"

echo
echo -e "${YELLOW}PHASE 1: INFRASTRUCTURE DEPLOYMENT${NC}"
echo -e "${YELLOW}=====================================${NC}"

# Initialize Terraform
echo -e "${GREEN}Initializing Terraform...${NC}"
cd "${TERRAFORM_DIR}"
terraform init

# Plan Terraform deployment
echo -e "${GREEN}Planning Terraform deployment...${NC}"
terraform plan -out=tfplan

# Confirm deployment
echo
echo -e "${YELLOW}Review the plan above. Do you want to apply it? (y/n)${NC}"
read -p "" CONFIRM
if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
  echo -e "${RED}Deployment aborted.${NC}"
  exit 1
fi

# Apply Terraform
echo -e "${GREEN}Applying Terraform configuration...${NC}"
terraform apply tfplan

# Get the admin VM IP
ADMIN_IP=$(terraform output -raw admin_public_ip)
echo -e "${GREEN}Admin VM IP: ${ADMIN_IP}${NC}"

# Create Ansible inventory
echo -e "${GREEN}Creating Ansible inventory...${NC}"
cd "${PROJECT_DIR}"
cat "${PLAYBOOKS_DIR}/inventory/hosts.ini.template" | \
  sed "s/{{ admin_ip }}/${ADMIN_IP}/g" | \
  sed "s/{{ admin_username }}/${ADMIN_USERNAME}/g" | \
  sed "s|{{ ssh_private_key_path }}|${SSH_PRIVATE_KEY}|g" \
  > "${PLAYBOOKS_DIR}/inventory/hosts.ini"

# Wait for SSH to be available
echo -e "${GREEN}Waiting for SSH to be available on admin VM...${NC}"
while ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$SSH_PRIVATE_KEY" "${ADMIN_USERNAME}@${ADMIN_IP}" echo "SSH is up"; do
  echo "Waiting for SSH connection..."
  sleep 10
done

echo
echo -e "${YELLOW}PHASE 2: ADMIN VM CONFIGURATION${NC}"
echo -e "${YELLOW}=====================================${NC}"

# Configure admin VM with Ansible
echo -e "${GREEN}Configuring admin VM with Ansible...${NC}"
cd "${PLAYBOOKS_DIR}"
ansible-playbook admin.yml

echo
echo -e "${YELLOW}PHASE 3: KUBERNETES DEPLOYMENT${NC}"
echo -e "${YELLOW}=====================================${NC}"

# Deploy Kubernetes applications
echo -e "${GREEN}Deploying Kubernetes applications...${NC}"
cd "${PLAYBOOKS_DIR}"
ansible-playbook k8s.yml -e "docker_hub_image=${DOCKER_HUB_IMAGE}" -e "docker_hub_tag=${DOCKER_HUB_TAG}"

echo
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Admin VM IP: ${ADMIN_IP}${NC}"
echo -e "${GREEN}SSH command: ssh -i ${SSH_PRIVATE_KEY} ${ADMIN_USERNAME}@${ADMIN_IP}${NC}"

# Get load balancer IP
cd "${TERRAFORM_DIR}"
LB_IP=$(terraform output -raw load_balancer_ip)
echo -e "${GREEN}Load Balancer IP: ${LB_IP}${NC}"
echo -e "${GREEN}Streaming server is available at: http://${LB_IP}${NC}"