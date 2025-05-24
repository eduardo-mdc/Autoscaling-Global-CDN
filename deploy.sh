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
ANSIBLE_VARS_SCRIPT="${PROJECT_DIR}/generate-ansible-vars.sh"

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

# Check if generate-ansible-vars.sh script exists
if [ ! -f "$ANSIBLE_VARS_SCRIPT" ]; then
  echo -e "${RED}Error: generate-ansible-vars.sh script not found${NC}"
  exit 1
fi

echo -e "${GREEN}All prerequisites are met.${NC}"
echo

# Set default value for ADMIN_USERNAME if not set in .env
ADMIN_USERNAME=${ADMIN_USERNAME:-ubuntu}

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

  # Get the admin VM IP and bastion IPs
  echo -e "${GREEN}Extracting Terraform outputs...${NC}"
  ADMIN_IP=$(terraform output -raw admin_public_ip)
  echo -e "${GREEN}Admin VM IP: ${ADMIN_IP}${NC}"

  # Get bastion internal IPs
  BASTION_IPS=$(terraform output -json bastion_internal_ips)
  echo -e "${GREEN}Bastion IPs extracted${NC}"

  # Return to project directory
  cd "${PROJECT_DIR}"

  # Generate Ansible variables from Terraform outputs
  echo -e "${GREEN}Generating Ansible variables from Terraform outputs...${NC}"
  chmod +x "$ANSIBLE_VARS_SCRIPT"
  "$ANSIBLE_VARS_SCRIPT" --force

  # Create Ansible inventory with admin and bastions
  echo -e "${GREEN}Creating Ansible inventory with jump host configuration...${NC}"

  INVENTORY_FILE="${PLAYBOOKS_DIR}/inventory/hosts.ini"
  mkdir -p "${PLAYBOOKS_DIR}/inventory"

  # Create inventory with admin and bastions (via jump host)
  cat > "$INVENTORY_FILE" << EOF
[admin]
admin-vm ansible_host=${ADMIN_IP} ansible_user=${ADMIN_USERNAME} ansible_ssh_private_key_file=${SSH_PRIVATE_KEY}

[bastions]
EOF

  # Add bastion hosts using jump host configuration
  echo "$BASTION_IPS" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read region ip; do
    echo "bastion-${region} ansible_host=${ip} ansible_user=${ADMIN_USERNAME} ansible_ssh_private_key_file=${SSH_PRIVATE_KEY} bastion_region=${region}" >> "$INVENTORY_FILE"
  done

  # Add group variables
  cat >> "$INVENTORY_FILE" << EOF

[admin:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
ansible_python_interpreter=/usr/bin/python3

[bastions:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyJump=${ADMIN_USERNAME}@${ADMIN_IP}'
ansible_python_interpreter=/usr/bin/python3

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

  echo -e "${GREEN}Inventory file created: ${INVENTORY_FILE}${NC}"
  echo -e "${YELLOW}Bastion hosts will be accessed via admin VM as jump host${NC}"


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

  # Clean up generated files
  cd "${PROJECT_DIR}"
  if [ -f "${PLAYBOOKS_DIR}/inventory/hosts.ini" ]; then
    rm "${PLAYBOOKS_DIR}/inventory/hosts.ini"
    echo -e "${GREEN}Cleaned up inventory file${NC}"
  fi

  if [ -f "${PLAYBOOKS_DIR}/group_vars/all.yaml" ]; then
    rm "${PLAYBOOKS_DIR}/group_vars/all.yaml"
    echo -e "${GREEN}Cleaned up Ansible variables file${NC}"
  fi
fi