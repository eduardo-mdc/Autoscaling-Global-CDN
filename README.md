# Autoscaling Global CDN
This project implements an autoscaling global Content Delivery Network (CDN) infrastructure on Azure using Terraform.

## Overview
The infrastructure consists of:

- Admin VM for management
- Regional subnet zones (Europe, America, Asia) for content distribution
- Network security groups with proper access controls
- Managed storage for content distribution

## Prerequisites
- Terraform (>= 1.0.0)
- Azure CLI
- Azure subscription

## Getting Started

Clone the Repository
```
git clone https://github.com/yourusername/Autoscaling-Global-CDN.git
cd Autoscaling-Global-CDN
```

2. Copy the environment template file to create your own .env file:
```
cp .env_template .env
```
3. Edit the .env file with your Azure credentials and configurations

4. Load the environment variables:
```
# For Linux/macOS
source .env

# For Windows PowerShell
Get-Content .env | ForEach-Object { 
    $name, $value = $_.split('=')
    if ($name -and $value) {
        Set-Content env:\$name $value
    }
}
```
## Deployment

1. Initialize Terraform:
```
cd infrastructure
terraform init
```

2. Change variables in `infrastructure/variables.tf` as needed.

3. Preview the changes:
```
terraform plan -var="$TF_VAR_subscription_id" -out=tfplan
```
4. Apply the changes to create the infrastructure:
```
terraform apply var="$TF_VAR_subscription_id" tfplan
```


## Cleanup 
To tear down the infrastructure:

```
terraform destroy
