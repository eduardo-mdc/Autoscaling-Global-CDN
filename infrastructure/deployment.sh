#!/bin/bash
# deployment.sh - Setup script for Scaleway serverless infrastructure

# Check if Scaleway CLI is installed
if ! command -v scw &> /dev/null; then
    echo "Scaleway CLI not found. Installing..."
    curl -o /tmp/scw -L "https://github.com/scaleway/scaleway-cli/releases/download/v2.31.0/scaleway-cli_2.31.0_linux_amd64"
    chmod +x /tmp/scw
    sudo mv /tmp/scw /usr/local/bin/
    echo "Scaleway CLI installed."
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform not found. Installing..."
    sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update && sudo apt-get install -y terraform
    echo "Terraform installed."
fi

# Set up Scaleway CLI configuration
echo "Configuring Scaleway CLI..."
read -p "Enter your Scaleway access key: " SCW_ACCESS_KEY
read -p "Enter your Scaleway secret key: " SCW_SECRET_KEY
read -p "Enter your Scaleway organization ID: " SCW_DEFAULT_ORGANIZATION_ID
read -p "Enter your Scaleway project ID: " SCW_DEFAULT_PROJECT_ID

scw config profile activate default
scw config set access-key=$SCW_ACCESS_KEY
scw config set secret-key=$SCW_SECRET_KEY
scw config set default-organization-id=$SCW_DEFAULT_ORGANIZATION_ID
scw config set default-project-id=$SCW_DEFAULT_PROJECT_ID
scw config set default-region=fr-par
scw config set default-zone=fr-par-1

echo "Scaleway CLI configured."

# Check if SSH key exists, generate if it doesn't
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "SSH key not found. Generating..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
    echo "SSH key generated at $SSH_KEY_PATH"
fi

# Read SSH public key for Terraform
SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")

# Create a temporary terraform.tfvars with the values
cat > terraform.tfvars <<EOF
project_name = "global-serverless"
scw_access_key = "$SCW_ACCESS_KEY"
scw_secret_key = "$SCW_SECRET_KEY"
scw_organization_id = "$SCW_DEFAULT_ORGANIZATION_ID"
scw_project_id = "$SCW_DEFAULT_PROJECT_ID"
ssh_public_key = "$SSH_PUBLIC_KEY"
regions = ["fr-par", "nl-ams"]
EOF

echo "Terraform variables file created."

# Initialize and apply Terraform
echo "Initializing Terraform..."
terraform init

echo "Deploying infrastructure with Terraform..."
terraform apply -auto-approve

echo "Infrastructure deployment complete!"
echo "--------------------------------------"
echo "Access your admin server with:"
echo "ssh admin@$(terraform output -raw admin_public_ip)"
echo ""
echo "Serverless endpoints:"
terraform output serverless_endpoints