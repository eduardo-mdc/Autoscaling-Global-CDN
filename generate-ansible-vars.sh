#!/bin/bash

# Script to generate Ansible variables from Terraform outputs
# This script should be run from the project root directory

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="terraform"
ANSIBLE_VARS_FILE="playbooks/group_vars/all.yaml"
TEMP_DIR="/tmp/terraform-outputs"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if terraform directory exists
check_terraform_dir() {
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        print_error "Terraform directory '$TERRAFORM_DIR' not found!"
        print_error "Please run this script from the project root directory."
        exit 1
    fi
}

# Function to check if terraform state exists
check_terraform_state() {
    if [[ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]] && [[ ! -f "$TERRAFORM_DIR/.terraform/terraform.tfstate" ]]; then
        print_error "No Terraform state found!"
        print_error "Please run 'terraform apply' first to create infrastructure."
        exit 1
    fi
}

# Function to get terraform output
get_terraform_output() {
    local output_name="$1"
    local raw_output=""

    cd "$TERRAFORM_DIR"

    if terraform output "$output_name" >/dev/null 2>&1; then
        raw_output=$(terraform output -raw "$output_name" 2>/dev/null || terraform output "$output_name")
        echo "$raw_output"
    else
        print_warning "Terraform output '$output_name' not found"
        echo ""
    fi

    cd - >/dev/null
}

# Function to get terraform output as JSON
get_terraform_output_json() {
    local output_name="$1"

    cd "$TERRAFORM_DIR"

    if terraform output "$output_name" >/dev/null 2>&1; then
        terraform output -json "$output_name"
    else
        print_warning "Terraform output '$output_name' not found"
        echo "{}"
    fi

    cd - >/dev/null
}

# Function to convert JSON to YAML format for Ansible
json_to_ansible_yaml() {
    local json_input="$1"

    # Use Python to convert JSON to YAML format
    echo "$json_input" | python3 -c "
import json
import sys

def yaml_dump(obj, indent=0):
    spaces = '  ' * indent
    if obj is None:
        return 'null'
    elif isinstance(obj, bool):
        return 'true' if obj else 'false'
    elif isinstance(obj, str):
        return f'\"{obj}\"'
    elif isinstance(obj, (int, float)):
        return str(obj)
    elif isinstance(obj, list):
        if not obj:
            return '[]'
        lines = []
        for item in obj:
            item_yaml = yaml_dump(item, indent + 1)
            if isinstance(item, (dict, list)) and item:
                lines.append(f'{spaces}- ')
                for line in item_yaml.split('\n'):
                    if line.strip():
                        lines.append(f'{spaces}  {line}')
            else:
                lines.append(f'{spaces}- {item_yaml}')
        return '\n'.join(lines)
    elif isinstance(obj, dict):
        if not obj:
            return '{}'
        lines = []
        for key, value in obj.items():
            value_yaml = yaml_dump(value, indent + 1)
            if isinstance(value, (dict, list)) and value:
                lines.append(f'{spaces}{key}:')
                for line in value_yaml.split('\n'):
                    if line.strip():
                        lines.append(f'{spaces}  {line}')
            else:
                lines.append(f'{spaces}{key}: {value_yaml}')
        return '\n'.join(lines)
    else:
        return str(obj)

try:
    data = json.load(sys.stdin)
    result = yaml_dump(data)
    print(result)
except json.JSONDecodeError:
    print('{}')
except Exception as e:
    print('{}')
"
}

# Function to get values from terraform.tfvars and terraform state
get_terraform_vars() {
    local project_id=""
    local project_name=""
    local regions=""
    local admin_username="admin"

    cd "$TERRAFORM_DIR"

    # Try to get values from terraform.tfvars first
    if [[ -f "terraform.tfvars" ]]; then
        # Extract values using grep and sed (silently)
        project_id=$(grep -E '^project_id\s*=' terraform.tfvars | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr -d '"' || echo "")
        project_name=$(grep -E '^project_name\s*=' terraform.tfvars | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr -d '"' || echo "")
        admin_username=$(grep -E '^admin_username\s*=' terraform.tfvars | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr -d '"' || echo "admin")

        # Extract regions array
        regions_line=$(grep -E '^regions\s*=' terraform.tfvars || echo "")
        if [[ -n "$regions_line" ]]; then
            regions=$(echo "$regions_line" | sed 's/.*=\s*\[\([^]]*\)\].*/\1/' | tr -d '"' | tr -d "'" | sed 's/,/ /g')
        fi
    fi

    # If still empty, try to extract from Terraform state
    if [[ -z "$project_id" ]] || [[ -z "$project_name" ]]; then
        # Try to get project_id from any google provider configuration in state
        if [[ -z "$project_id" ]]; then
            project_id=$(terraform show -json 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    # Look for project in provider config or resources
    if 'values' in data and 'root_module' in data['values']:
        for resource in data['values']['root_module'].get('resources', []):
            if 'values' in resource and 'project' in resource['values']:
                print(resource['values']['project'])
                break
except:
    pass
" 2>/dev/null || echo "")
        fi
    fi

    # Fallback: try to get from any terraform output that might contain these values
    if [[ -z "$project_id" ]]; then
        project_id=$(terraform output -raw project_id 2>/dev/null || echo "")
    fi

    if [[ -z "$project_name" ]]; then
        project_name=$(terraform output -raw project_name 2>/dev/null || echo "")
    fi

    # Get regions from network_details or gke_clusters output if not found in tfvars
    if [[ -z "$regions" ]]; then
        regions=$(terraform output -json gke_clusters 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    regions = list(data.keys())
    print(' '.join(regions))
except:
    pass
" || echo "")
    fi

    cd - >/dev/null

    # Convert regions to YAML array format
    local regions_yaml="[]"
    if [[ -n "$regions" ]]; then
        regions_yaml=$(echo "$regions" | python3 -c "
import sys
regions_str = sys.stdin.read().strip()
if regions_str:
    regions = [r.strip() for r in regions_str.replace(',', ' ').split() if r.strip()]
    for r in regions:
        print(f'  - \"{r}\"')
")
    fi

    cat << EOF
# Configuration values from Terraform
project_id: "$project_id"
project_name: "$project_name"
admin_username: "$admin_username"
regions:
$regions_yaml
EOF
}

# Function to create the ansible vars file
create_ansible_vars() {
    print_status "Creating Ansible variables file..."

    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$ANSIBLE_VARS_FILE")"

    # Create temporary directory
    mkdir -p "$TEMP_DIR"

    print_status "Fetching Terraform outputs..."

    # Get all terraform outputs
    local admin_public_ip
    local admin_ssh_command
    local gke_clusters_json
    local gke_connect_commands_json
    local load_balancer_ip
    local network_details_json
    local ssh_key_debug
    local bastion_internal_ips_json
    local bastion_ssh_via_admin_json
    local domain_configuration_json
    local deployment_urls_json
    local nameserver_instructions_json

    bastion_internal_ips_json=$(get_terraform_output_json "bastion_internal_ips")
    bastion_ssh_via_admin_json=$(get_terraform_output_json "bastion_ssh_via_admin")
    domain_configuration_json=$(get_terraform_output_json "domain_configuration")
    deployment_urls_json=$(get_terraform_output_json "deployment_urls")
    nameserver_instructions_json=$(get_terraform_output_json "nameserver_instructions")

    admin_public_ip=$(get_terraform_output "admin_public_ip")
    admin_ssh_command=$(get_terraform_output "admin_ssh_command")
    gke_clusters_json=$(get_terraform_output_json "gke_clusters")
    gke_connect_commands_json=$(get_terraform_output_json "gke_connect_commands")
    load_balancer_ip=$(get_terraform_output "load_balancer_ip")
    network_details_json=$(get_terraform_output_json "network_details")
    ssh_key_debug=$(get_terraform_output "ssh_key_debug")

    # Get terraform vars (without printing status messages to the file)
    local terraform_vars
    terraform_vars=$(get_terraform_vars)

    # Create the YAML file
    cat > "$ANSIBLE_VARS_FILE" << EOF
---
# Ansible variables generated from Terraform outputs
# Generated on: $(date)
# Do not edit this file manually - it will be overwritten

$terraform_vars

# Terraform outputs
admin_public_ip: "$admin_public_ip"
admin_ssh_command: "$admin_ssh_command"
load_balancer_ip: "$load_balancer_ip"
ssh_key_debug: "$ssh_key_debug"

# Domain Configuration
domain_configuration:
$(json_to_ansible_yaml "$domain_configuration_json" | sed 's/^/  /')

# Deployment URLs
deployment_urls:
$(json_to_ansible_yaml "$deployment_urls_json" | sed 's/^/  /')

# Nameserver Instructions
nameserver_instructions:
$(json_to_ansible_yaml "$nameserver_instructions_json" | sed 's/^/  /')

# GKE Clusters
gke_clusters:
$(json_to_ansible_yaml "$gke_clusters_json" | sed 's/^/  /')

# GKE Connect Commands
gke_connect_commands:
$(json_to_ansible_yaml "$gke_connect_commands_json" | sed 's/^/  /')

# Network Details
network_details:
$(json_to_ansible_yaml "$network_details_json" | sed 's/^/  /')

# Bastion Hosts
bastion_internal_ips:
$(json_to_ansible_yaml "$bastion_internal_ips_json" | sed 's/^/  /')

# Bastion SSH Commands via Admin
bastion_ssh_via_admin:
$(json_to_ansible_yaml "$bastion_ssh_via_admin_json" | sed 's/^/  /')

# Ingress Configuration for managed SSL
ssl_cert_type: "managed"
domain_name: "$(echo "$domain_configuration_json" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('domain_name', ''))" 2>/dev/null || echo "")"

# Environment (can be overridden per deployment)
environment: "production"
EOF

    # Clean up temp directory
    rm -rf "$TEMP_DIR"

    print_status "Ansible variables file created: $ANSIBLE_VARS_FILE"
}

# Function to validate the created file
validate_ansible_vars() {
    print_status "Validating Ansible variables file..."

    if [[ ! -f "$ANSIBLE_VARS_FILE" ]]; then
        print_error "Ansible variables file was not created!"
        exit 1
    fi

    # Check if file is valid YAML using Python
    if python3 -c "
import yaml
import sys
try:
    with open('$ANSIBLE_VARS_FILE', 'r') as f:
        yaml.safe_load(f)
    print('YAML is valid')
except Exception as e:
    print(f'YAML validation failed: {e}')
    sys.exit(1)
" 2>/dev/null; then
        print_status "YAML validation passed"
    else
        print_warning "YAML validation failed, but file was created"
        print_warning "Please check the file manually: $ANSIBLE_VARS_FILE"
    fi
}

# Main function
main() {
    print_status "Starting Ansible variables generation from Terraform outputs..."

    # Check prerequisites
    check_terraform_dir
    check_terraform_state

    # Check if required tools are available
    if ! command -v python3 &> /dev/null; then
        print_error "python3 is required but not installed"
        exit 1
    fi

    if ! python3 -c "import yaml" 2>/dev/null; then
        print_warning "PyYAML not found, installing..."
        pip3 install pyyaml || {
            print_error "Failed to install PyYAML"
            exit 1
        }
    fi

    # Create the variables file
    create_ansible_vars

    # Validate the file
    validate_ansible_vars

    print_status "Done! You can now use the variables in your Ansible playbooks."
    print_status "File location: $ANSIBLE_VARS_FILE"

    # Show a preview of the file
    echo
    print_status "Preview of generated file:"
    echo "----------------------------------------"
    head -20 "$ANSIBLE_VARS_FILE"
    echo "..."
    echo "----------------------------------------"
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate Ansible variables from Terraform outputs for multi-region GKE deployment.

OPTIONS:
    -h, --help          Show this help message
    -v, --validate      Only validate existing Ansible variables file
    -f, --force         Force regeneration even if file exists

ENVIRONMENT VARIABLES:
    These are now automatically extracted from terraform.tfvars and Terraform state.
    No manual environment variables need to be set.

EXAMPLES:
    # Basic usage
    $0

    # Force regeneration
    $0 --force

    # Only validate existing file
    $0 --validate

NOTES:
    - Run this script from the project root directory
    - Ensure Terraform has been applied successfully
    - The script will create playbooks/group_vars/terraform.yaml
EOF
}

# Parse command line arguments
FORCE=false
VALIDATE_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--validate)
            VALIDATE_ONLY=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Execute based on options
if [[ "$VALIDATE_ONLY" == true ]]; then
    validate_ansible_vars
elif [[ "$FORCE" == true ]] || [[ ! -f "$ANSIBLE_VARS_FILE" ]]; then
    main
else
    print_warning "Ansible variables file already exists: $ANSIBLE_VARS_FILE"
    print_warning "Use --force to regenerate or --validate to check existing file"
    exit 1
fi