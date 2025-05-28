#!/bin/bash

# 3-Phase Deployment Script for Multi-Region Streaming Infrastructure
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR=$(pwd)
TERRAFORM_DIR="${PROJECT_DIR}/terraform"
PLAYBOOKS_DIR="${PROJECT_DIR}/playbooks"
SSH_PRIVATE_KEY="$HOME/.ssh/id_rsa"
SSH_PUBLIC_KEY="$HOME/.ssh/id_rsa.pub"
ANSIBLE_VARS_SCRIPT="${PROJECT_DIR}/generate-ansible-vars.sh"

# Default values
OPERATION="deploy"
PHASE="all"
SKIP_CONFIRMATION=false
DOCKER_IMAGE=""
DOCKER_TAG="latest"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} $1 ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
}

print_phase() {
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN} PHASE $1: $2 ${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Multi-Region Streaming Infrastructure Deployment

OPTIONS:
    --phase <phase>         Deploy specific phase (1, 2, 3, or all) [default: all]
    --operation <op>        Operation: deploy, destroy, plan [default: deploy]
    --docker-image <image>  Docker image for streaming server
    --docker-tag <tag>      Docker tag [default: latest]
    --skip-confirmation     Skip confirmation prompts
    --help                  Show this help message

PHASES:
    1   Infrastructure     Deploy Terraform infrastructure (VMs, networks, GKE)
    2   Kubernetes        Setup Kubernetes access and basic resources
    3   Applications      Deploy streaming server and admin webapp
    all Deploy all phases sequentially

OPERATIONS:
    deploy    Deploy infrastructure and applications
    destroy   Destroy all infrastructure
    plan      Show deployment plan without applying

EXAMPLES:
    # Deploy everything
    $0

    # Deploy only infrastructure
    $0 --phase 1

    # Deploy with custom Docker image
    $0 --docker-image myregistry/streaming-server --docker-tag v1.2.3

    # Plan deployment without applying
    $0 --operation plan

    # Destroy everything
    $0 --operation destroy --skip-confirmation

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --phase)
                PHASE="$2"
                shift 2
                ;;
            --operation)
                OPERATION="$2"
                shift 2
                ;;
            --docker-image)
                DOCKER_IMAGE="$2"
                shift 2
                ;;
            --docker-tag)
                DOCKER_TAG="$2"
                shift 2
                ;;
            --skip-confirmation)
                SKIP_CONFIRMATION=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Validate phase
    if [[ ! "$PHASE" =~ ^(1|2|3|all)$ ]]; then
        print_error "Invalid phase: $PHASE. Must be 1, 2, 3, or all"
        exit 1
    fi

    # Validate operation
    if [[ ! "$OPERATION" =~ ^(deploy|destroy|plan)$ ]]; then
        print_error "Invalid operation: $OPERATION. Must be deploy, destroy, or plan"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check required directories
    if [ ! -d "$TERRAFORM_DIR" ]; then
        print_error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi

    if [ ! -d "$PLAYBOOKS_DIR" ]; then
        print_error "Playbooks directory not found: $PLAYBOOKS_DIR"
        exit 1
    fi

    # Check tools
    local missing_tools=()

    command -v terraform >/dev/null || missing_tools+=("terraform")
    command -v ansible >/dev/null || missing_tools+=("ansible")
    command -v kubectl >/dev/null || missing_tools+=("kubectl")
    command -v gcloud >/dev/null || missing_tools+=("gcloud")

    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install them before continuing."
        exit 1
    fi

    # Check SSH keys
    if [ ! -f "$SSH_PRIVATE_KEY" ] || [ ! -f "$SSH_PUBLIC_KEY" ]; then
        print_error "SSH keys not found. Please generate them:"
        print_error "ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa"
        exit 1
    fi

    # Check Ansible vars script or create placeholder
    if [ ! -f "$ANSIBLE_VARS_SCRIPT" ]; then
        print_warning "Ansible variables script not found. Creating placeholder..."
        cat > "$ANSIBLE_VARS_SCRIPT" << 'EOF'
#!/bin/bash
# Placeholder script - replace with actual Terraform output to Ansible vars conversion
echo "Generating Ansible variables from Terraform outputs..."
cd terraform
terraform output -json > ../playbooks/group_vars/all/terraform_outputs.json
EOF
        chmod +x "$ANSIBLE_VARS_SCRIPT"
    fi

    print_success "All prerequisites met"
    echo
}

# Create Ansible inventory
create_ansible_inventory() {
    print_status "Creating Ansible inventory..."

    local admin_ip
    local inventory_file="${PLAYBOOKS_DIR}/inventory/hosts.ini"

    cd "$TERRAFORM_DIR"

    # Get admin IP from Terraform
    admin_ip=$(terraform output -raw admin_public_ip 2>/dev/null || echo "")

    if [ -z "$admin_ip" ]; then
        print_error "Could not get admin IP from Terraform outputs"
        return 1
    fi

    # Get bastion IPs
    local bastion_ips
    bastion_ips=$(terraform output -json bastion_internal_ips 2>/dev/null || echo "{}")

    cd "$PROJECT_DIR"

    # Create inventory directory
    mkdir -p "${PLAYBOOKS_DIR}/inventory"

    # Create inventory file
    cat > "$inventory_file" << EOF
[admin]
admin-vm ansible_host=${admin_ip} ansible_user=${ADMIN_USERNAME:-ubuntu} ansible_ssh_private_key_file=${SSH_PRIVATE_KEY}

[bastions]
EOF

    # Add bastion hosts
    if [ "$bastion_ips" != "{}" ]; then
        echo "$bastion_ips" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for region, ip in data.items():
    print(f'bastion-{region} ansible_host={ip} ansible_user=${ADMIN_USERNAME:-ubuntu} ansible_ssh_private_key_file=${SSH_PRIVATE_KEY} bastion_region={region}')
" >> "$inventory_file"
    fi

    # Add group variables
    cat >> "$inventory_file" << 'EOF'

[admin:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
ansible_python_interpreter=/usr/bin/python3

[bastions:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyJump=ubuntu@ADMIN_IP'
ansible_python_interpreter=/usr/bin/python3

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

    # Replace ADMIN_IP placeholder
    sed -i "s/ADMIN_IP/${admin_ip}/g" "$inventory_file"

    print_success "Inventory created: $inventory_file"
}

# ============================================================================
# PHASE 1: INFRASTRUCTURE DEPLOYMENT
# ============================================================================

deploy_phase1() {
    print_phase "1" "INFRASTRUCTURE DEPLOYMENT"

    cd "$TERRAFORM_DIR"

    # Delete existing zip file if it exists
    if [ -f "functions/cold-autoscaler.zip" ]; then
        print_status "Removing existing cold-autoscaler.zip..."
        rm "functions/cold-autoscaler.zip"
    fi

    # Create new zip file from cold-autoscaler directory
    if [ -d "functions/cold-autoscaler" ]; then
        print_status "Creating cold-autoscaler.zip from source directory..."
        cd "functions/cold-autoscaler"
        zip -r ../cold-autoscaler.zip ./*
        cd "$TERRAFORM_DIR"
        print_success "Created cold-autoscaler.zip"
    else
        print_warning "cold-autoscaler directory not found, skipping zip creation"
    fi

    print_status "Initializing Terraform..."
    terraform init

    if [ "$OPERATION" = "plan" ]; then
        print_status "Showing Terraform plan..."
        terraform plan
        return 0
    fi

    print_status "Planning infrastructure deployment..."
    terraform plan -out=tfplan

    if [ "$OPERATION" = "destroy" ]; then
        if [ "$SKIP_CONFIRMATION" = false ]; then
            print_warning "⚠️  WARNING: This will DESTROY all infrastructure!"
            read -p "Type 'destroy' to confirm: " confirm
            if [ "$confirm" != "destroy" ]; then
                print_error "Destroy operation cancelled"
                exit 1
            fi
        fi

        print_status "Destroying infrastructure..."
        terraform destroy -auto-approve
        print_success "Infrastructure destroyed"
        return 0
    fi

    if [ "$SKIP_CONFIRMATION" = false ]; then
        echo
        print_warning "Review the Terraform plan above."
        read -p "Apply this plan? (y/N): " -r response < /dev/tty
        echo
        if [[ ! $response =~ ^[Yy]$ ]]; then
            print_error "Phase 1 cancelled by user"
            exit 1
        fi
    fi

    print_status "Applying Terraform configuration..."
    terraform apply tfplan

    print_success "✅ Phase 1 completed - Infrastructure deployed"

    # Display key outputs
    echo
    print_status "Infrastructure Summary:"
    echo -e "${CYAN}Admin VM SSH:${NC} $(terraform output -raw admin_ssh_command 2>/dev/null || echo 'Not available')"
    echo -e "${CYAN}Admin Webapp:${NC} $(terraform output -raw admin_webapp_urls 2>/dev/null | grep -o 'ip_url.*' || echo 'Not available')"
    echo -e "${CYAN}Streaming LB:${NC} $(terraform output -raw load_balancer_ip 2>/dev/null || echo 'Not available')"
    echo

    cd "$PROJECT_DIR"
}

# ============================================================================
# PHASE 2: KUBERNETES SETUP
# ============================================================================

deploy_phase2() {
    print_phase "2" "KUBERNETES SETUP"

    # Generate Ansible variables from Terraform outputs
    print_status "Generating Ansible variables from Terraform outputs..."
    chmod +x "$ANSIBLE_VARS_SCRIPT"
    "$ANSIBLE_VARS_SCRIPT" --force || true

    # Create Ansible inventory
    print_status "Creating Ansible inventory..."
    create_ansible_inventory

    cd "$PLAYBOOKS_DIR"

    # Test connectivity
    print_status "Testing connectivity to admin VM..."
    if ! ansible admin -m ping >/dev/null 2>&1; then
        print_warning "Cannot reach admin VM yet. Waiting 30 seconds..."
        sleep 30
        if ! ansible admin -m ping; then
            print_error "Cannot connect to admin VM. Check SSH configuration."
            exit 1
        fi
    fi

    # Phase 2a: Setup admin and bastion hosts
    print_status "Setting up admin and bastion hosts..."
    ansible-playbook streaming-deployment.yaml --tags "phase1" || {
        print_error "Failed to setup admin and bastion hosts"
        exit 1
    }

    print_success "✅ Phase 2 completed - Kubernetes ready"
    echo

    cd "$PROJECT_DIR"
}

# ============================================================================
# PHASE 3: APPLICATIONS DEPLOYMENT
# ============================================================================

deploy_phase3() {
    print_phase "3" "APPLICATIONS DEPLOYMENT"

    cd "$PLAYBOOKS_DIR"

    # Set Docker image variables if provided
    extra_vars=""
    if [ -n "$DOCKER_IMAGE" ]; then
        extra_vars="--extra-vars docker_hub_image=$DOCKER_IMAGE"
        if [ -n "$DOCKER_TAG" ]; then
            extra_vars="$extra_vars --extra-vars docker_hub_tag=$DOCKER_TAG"
        fi
    fi

    # Phase 3a: Deploy streaming applications
    print_status "Deploying streaming server..."
    ansible-playbook streaming-deployment.yaml --tags "phase2" $extra_vars || {
        print_error "Failed to deploy streaming applications"
        exit 1
    }

    # Phase 3b: Verify deployment
    print_status "Verifying deployment..."
    ansible-playbook streaming-deployment.yaml --tags "phase3" || {
        print_warning "Verification completed with warnings - check output above"
    }

    print_success "✅ Phase 3 completed - Applications deployed"
    echo

    cd "$PROJECT_DIR"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "MULTI-REGION STREAMING INFRASTRUCTURE DEPLOYMENT"

    # Parse arguments
    parse_args "$@"

    # Check prerequisites
    check_prerequisites

    # Execute phases based on selection
    case "$PHASE" in
        "1")
            deploy_phase1
            ;;
        "2")
            deploy_phase2
            ;;
        "3")
            deploy_phase3
            ;;
        "all")
            deploy_phase1
            if [ "$OPERATION" != "destroy" ] && [ "$OPERATION" != "plan" ]; then
                deploy_phase2
                deploy_phase3

                print_header "DEPLOYMENT COMPLETE"
                print_success "🎉 All phases completed successfully!"
                echo
                print_status "Next steps:"
                echo "1. Access admin webapp: Check terraform outputs for admin webapp URL"
                echo "2. Access streaming service: Check terraform outputs for load balancer IP"
                echo "3. Upload content via admin VM and sync to regional buckets"
                echo
            fi
            ;;
    esac
}

# Run main function with all arguments
main "$@"