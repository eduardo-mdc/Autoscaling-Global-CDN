#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color


# Default operation mode
OPERATION="apply"

# Parse command line arguments
if [[ $# -gt 0 ]]; then
  case "$1" in
    --apply)
      OPERATION="apply"
      ;;
    --destroy)
      OPERATION="destroy"
      ;;
    --help)
      echo "Usage: $0 [--apply|--destroy|--help]"
      echo
      echo "Options:"
      echo "  --apply     Deploy the infrastructure (default)"
      echo "  --destroy   Destroy the infrastructure"
      echo "  --help      Show this help message"
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${NC}"
      echo "Usage: $0 [--apply|--destroy|--help]"
      exit 1
      ;;
  esac
fi


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

# Check if .env file exists
if [ -f ".env" ]; then
  echo -e "${GREEN}Loading configuration from .env file...${NC}"
  # Source the .env file
  source .env
else
  echo -e "${RED}Error: .env file not found${NC}"
  echo -e "${YELLOW}Please create a .env file with the following variables:${NC}"
  echo "PROJECT_ID=your-gcp-project-id"
  echo "PROJECT_NAME=your-project-name"
  echo "DOCKER_HUB_IMAGE=username/image"
  echo "DOCKER_HUB_TAG=latest"
  echo "ADMIN_USERNAME=admin"
  exit 1
fi

# Set default value for ADMIN_USERNAME if not set in .env
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}

# Display loaded configuration
echo -e "${GREEN}Loaded configuration:${NC}"
echo -e "GCP Project ID: ${YELLOW}${PROJECT_ID}${NC}"
echo -e "Project Name: ${YELLOW}${PROJECT_NAME}${NC}"
echo -e "Docker Hub Image: ${YELLOW}${DOCKER_HUB_IMAGE}${NC}"
echo -e "Docker Hub Tag: ${YELLOW}${DOCKER_HUB_TAG}${NC}"
echo -e "Admin Username: ${YELLOW}${ADMIN_USERNAME}${NC}"

# Export variables for Ansible
export ANSIBLE_REGIONS="${TF_VAR_regions:-europe-west4,us-east1,asia-southeast1}"

echo
echo -e "${YELLOW}PHASE 1: INFRASTRUCTURE ${OPERATION^^}${NC}"
echo -e "${YELLOW}=====================================${NC}"

# Initialize Terraform
echo -e "${GREEN}Initializing Terraform...${NC}"
cd "${TERRAFORM_DIR}"
terraform init

if [ "$OPERATION" == "apply" ]; then
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
else
  # Destroy confirmation
  echo -e "${RED}WARNING: This will destroy all infrastructure resources!${NC}"
  echo -e "${YELLOW}Are you sure you want to destroy the infrastructure? (type 'destroy' to confirm)${NC}"
  read -p "" CONFIRM
  if [[ $CONFIRM != "destroy" ]]; then
    echo -e "${RED}Destroy operation aborted.${NC}"
    exit 1
  fi

  # Destroy infrastructure
  echo -e "${GREEN}Destroying infrastructure...${NC}"
  terraform destroy -auto-approve

  echo -e "${GREEN}Infrastructure successfully destroyed.${NC}"
fi