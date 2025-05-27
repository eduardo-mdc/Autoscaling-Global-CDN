#!/bin/bash
# Terraform Import Script for Multi-Region GKE Streaming Infrastructure
# This script imports all existing infrastructure into Terraform state without prior state

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="terraform"
PROJECT_ID=""
PROJECT_NAME=""
REGIONS=()
ZONES=()
ADMIN_USERNAME="ubuntu"

# Script options
DRY_RUN=false
VERBOSE=false
CONTINUE_ON_ERROR=true
IMPORT_LOG="terraform-import-$(date +%Y%m%d-%H%M%S).log"

# Function to print colored output
print_header() {
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE}    Terraform Infrastructure Import Script    ${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$IMPORT_LOG"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$IMPORT_LOG"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$IMPORT_LOG"
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}" | tee -a "$IMPORT_LOG"
}

# Function to load configuration from terraform.tfvars
load_terraform_config() {
    print_status "Loading configuration from terraform.tfvars..."

    if [[ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]]; then
        print_error "terraform.tfvars not found in $TERRAFORM_DIR"
        exit 1
    fi

    cd "$TERRAFORM_DIR"

    # Extract configuration values
    PROJECT_ID=$(grep -E '^project_id\s*=' terraform.tfvars | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr -d '"' || echo "")
    PROJECT_NAME=$(grep -E '^project_name\s*=' terraform.tfvars | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr -d '"' || echo "")
    ADMIN_USERNAME=$(grep -E '^admin_username\s*=' terraform.tfvars | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr -d '"' || echo "ubuntu")

    # Extract regions array
    regions_line=$(grep -E '^regions\s*=' terraform.tfvars || echo "")
    if [[ -n "$regions_line" ]]; then
        # Parse regions array - handle both formats: ["region1", "region2"] and ["region1","region2"]
        regions_raw=$(echo "$regions_line" | sed 's/.*=\s*\[\([^]]*\)\].*/\1/' | tr -d ' ')
        IFS=',' read -ra regions_array <<< "$regions_raw"
        for region in "${regions_array[@]}"; do
            clean_region=$(echo "$region" | tr -d '"' | tr -d "'")
            REGIONS+=("$clean_region")
        done
    fi

    # Extract zones mapping
    zones_start=$(grep -n "^zones\s*=" terraform.tfvars | cut -d: -f1 || echo "")
    if [[ -n "$zones_start" ]]; then
        # Read zones block
        zones_content=$(sed -n "${zones_start},/^}/p" terraform.tfvars)
        while IFS= read -r line; do
            if [[ $line =~ \"([^\"]+)\"\s*=\s*\"([^\"]+)\" ]]; then
                region="${BASH_REMATCH[1]}"
                zone="${BASH_REMATCH[2]}"
                ZONES+=("$region:$zone")
            fi
        done <<< "$zones_content"
    fi

    cd - >/dev/null

    print_status "Configuration loaded:"
    print_status "  Project ID: $PROJECT_ID"
    print_status "  Project Name: $PROJECT_NAME"
    print_status "  Admin Username: $ADMIN_USERNAME"
    print_status "  Regions: ${REGIONS[*]}"
    print_status "  Zones: ${ZONES[*]}"

    # Validate required values
    if [[ -z "$PROJECT_ID" || -z "$PROJECT_NAME" || ${#REGIONS[@]} -eq 0 ]]; then
        print_error "Missing required configuration values"
        print_error "Ensure project_id, project_name, and regions are set in terraform.tfvars"
        exit 1
    fi
}

# Function to get zone for region
get_zone_for_region() {
    local region="$1"
    for zone_mapping in "${ZONES[@]}"; do
        if [[ $zone_mapping == "$region:"* ]]; then
            echo "${zone_mapping#*:}"
            return
        fi
    done
    # Default zone pattern if not specified
    echo "${region}-a"
}

# Function to check if resource exists
resource_exists() {
    local resource_type="$1"
    local resource_name="$2"
    local project="$3"
    local region="${4:-}"
    local zone="${5:-}"

    case "$resource_type" in
        "compute_instance")
            if [[ -n "$zone" ]]; then
                gcloud compute instances describe "$resource_name" --zone="$zone" --project="$project" &>/dev/null
            else
                print_error "Zone required for compute_instance"
                return 1
            fi
            ;;
        "compute_network")
            gcloud compute networks describe "$resource_name" --project="$project" &>/dev/null
            ;;
        "compute_subnetwork")
            if [[ -n "$region" ]]; then
                gcloud compute subnetworks describe "$resource_name" --region="$region" --project="$project" &>/dev/null
            else
                print_error "Region required for compute_subnetwork"
                return 1
            fi
            ;;
        "compute_firewall")
            gcloud compute firewall-rules describe "$resource_name" --project="$project" &>/dev/null
            ;;
        "compute_address")
            if [[ -n "$region" ]]; then
                gcloud compute addresses describe "$resource_name" --region="$region" --project="$project" &>/dev/null
            else
                gcloud compute addresses describe "$resource_name" --global --project="$project" &>/dev/null
            fi
            ;;
        "container_cluster")
            if [[ -n "$region" ]]; then
                gcloud container clusters describe "$resource_name" --region="$region" --project="$project" &>/dev/null
            else
                print_error "Region required for container_cluster"
                return 1
            fi
            ;;
        "container_node_pool")
            if [[ -n "$region" ]]; then
                local cluster_name="$6"
                gcloud container node-pools describe "$resource_name" --cluster="$cluster_name" --region="$region" --project="$project" &>/dev/null
            else
                print_error "Region and cluster required for container_node_pool"
                return 1
            fi
            ;;
        "storage_bucket")
            gsutil ls -b "gs://$resource_name" &>/dev/null
            ;;
        "dns_managed_zone")
            gcloud dns managed-zones describe "$resource_name" --project="$project" &>/dev/null
            ;;
        "compute_global_address")
            gcloud compute addresses describe "$resource_name" --global --project="$project" &>/dev/null
            ;;
        "compute_ssl_certificate")
            gcloud compute ssl-certificates describe "$resource_name" --global --project="$project" &>/dev/null
            ;;
        "service_account")
            gcloud iam service-accounts describe "${resource_name}@${project}.iam.gserviceaccount.com" --project="$project" &>/dev/null
            ;;
        "compute_network_peering")
            local network_name="$6"
            gcloud compute networks peerings list --network="$network_name" --project="$project" --format="value(name)" | grep -q "^$resource_name$"
            ;;
        "custom_role")
            gcloud iam roles describe "$resource_name" --project="$project" &>/dev/null
            ;;
        *)
            print_warning "Unknown resource type: $resource_type"
            return 1
            ;;
    esac
}

# Function to import a resource
import_resource() {
    local terraform_address="$1"
    local gcp_resource_id="$2"
    local description="$3"

    if [[ "$DRY_RUN" == true ]]; then
        print_status "DRY RUN: Would import $description"
        print_status "  Terraform: $terraform_address"
        print_status "  GCP ID: $gcp_resource_id"
        return 0
    fi

    print_status "Importing $description..."
    if [[ "$VERBOSE" == true ]]; then
        print_status "  Terraform: $terraform_address"
        print_status "  GCP ID: $gcp_resource_id"
    fi

    if terraform import "$terraform_address" "$gcp_resource_id" 2>>"$IMPORT_LOG"; then
        print_status "✅ Successfully imported $description"
        return 0
    else
        print_error "❌ Failed to import $description"
        #if [[ "$CONTINUE_ON_ERROR" == false ]]; then
        #     exit 1
        #fi
        return 1
    fi
}

# Function to import admin module resources
import_admin_module() {
    print_section "Importing Admin Module Resources"

    local admin_vm_name="${PROJECT_NAME}-admin"
    local admin_vpc_name="${PROJECT_NAME}-admin-vpc"
    local admin_subnet_name="${PROJECT_NAME}-admin-subnet"
    local admin_ip_name="${PROJECT_NAME}-admin-ip"
    local admin_zone=$(get_zone_for_region "${REGIONS[0]}")
    local admin_region="${REGIONS[0]}"

    # Import admin VPC
    if resource_exists "compute_network" "$admin_vpc_name" "$PROJECT_ID"; then
        import_resource \
            "module.admin.google_compute_network.admin_vpc" \
            "projects/$PROJECT_ID/global/networks/$admin_vpc_name" \
            "Admin VPC Network"
    fi

    # Import admin subnet
    if resource_exists "compute_subnetwork" "$admin_subnet_name" "$PROJECT_ID" "$admin_region"; then
        import_resource \
            "module.admin.google_compute_subnetwork.admin_subnet" \
            "projects/$PROJECT_ID/regions/$admin_region/subnetworks/$admin_subnet_name" \
            "Admin Subnet"
    fi

    # Import admin static IP
    if resource_exists "compute_address" "$admin_ip_name" "$PROJECT_ID" "$admin_region"; then
        import_resource \
            "module.admin.google_compute_address.admin_ip" \
            "projects/$PROJECT_ID/regions/$admin_region/addresses/$admin_ip_name" \
            "Admin Static IP"
    fi

    # Import admin VM
    if resource_exists "compute_instance" "$admin_vm_name" "$PROJECT_ID" "" "$admin_zone"; then
        import_resource \
            "module.admin.google_compute_instance.admin" \
            "projects/$PROJECT_ID/zones/$admin_zone/instances/$admin_vm_name" \
            "Admin VM Instance"
    fi

    # Import admin SSH firewall rule
    local admin_ssh_fw="${PROJECT_NAME}-admin-ssh"
    if resource_exists "compute_firewall" "$admin_ssh_fw" "$PROJECT_ID"; then
        import_resource \
            "module.admin.google_compute_firewall.admin_ssh" \
            "projects/$PROJECT_ID/global/firewalls/$admin_ssh_fw" \
            "Admin SSH Firewall Rule"
    fi

    # Import admin allow from GKE masters firewall rule
    local admin_gke_fw="${PROJECT_NAME}-admin-allow-from-gke-masters"
    if resource_exists "compute_firewall" "$admin_gke_fw" "$PROJECT_ID"; then
        import_resource \
            "module.admin.google_compute_firewall.admin_allow_from_gke_masters" \
            "projects/$PROJECT_ID/global/firewalls/$admin_gke_fw" \
            "Admin GKE Masters Firewall Rule"
    fi
}

# Function to import network module resources
import_network_modules() {
    print_section "Importing Network Module Resources"

    for region in "${REGIONS[@]}"; do
        print_status "Importing network resources for region: $region"

        local vpc_name="${PROJECT_NAME}-vpc-${region}"
        local subnet_name="${PROJECT_NAME}-subnet-${region}"
        local router_name="${PROJECT_NAME}-router-${region}"
        local nat_name="${PROJECT_NAME}-nat-${region}"

        # Import VPC
        if resource_exists "compute_network" "$vpc_name" "$PROJECT_ID"; then
            import_resource \
                "module.network[\"$region\"].google_compute_network.vpc" \
                "projects/$PROJECT_ID/global/networks/$vpc_name" \
                "VPC Network ($region)"
        fi

        # Import subnet
        if resource_exists "compute_subnetwork" "$subnet_name" "$PROJECT_ID" "$region"; then
            import_resource \
                "module.network[\"$region\"].google_compute_subnetwork.subnet" \
                "projects/$PROJECT_ID/regions/$region/subnetworks/$subnet_name" \
                "Subnet ($region)"
        fi

        # Import router
        if gcloud compute routers describe "$router_name" --region="$region" --project="$PROJECT_ID" &>/dev/null; then
            import_resource \
                "module.network[\"$region\"].google_compute_router.router" \
                "projects/$PROJECT_ID/regions/$region/routers/$router_name" \
                "Cloud Router ($region)"
        fi

        # Import NAT gateway
        if gcloud compute routers nats describe "$nat_name" --router="$router_name" --region="$region" --project="$PROJECT_ID" &>/dev/null; then
            import_resource \
                "module.network[\"$region\"].google_compute_router_nat.nat" \
                "projects/$PROJECT_ID/regions/$region/routers/$router_name/$nat_name" \
                "Cloud NAT ($region)"
        fi

        # Import firewall rules
        local firewall_rules=(
            "${PROJECT_NAME}-allow-internet-egress-${region}"
            "${PROJECT_NAME}-allow-egress-to-admin-${region}"
            "${PROJECT_NAME}-allow-internal-${region}"
            "${PROJECT_NAME}-allow-from-admin-${region}"
            "${PROJECT_NAME}-block-inter-region-${region}"
        )

        for fw_rule in "${firewall_rules[@]}"; do
            if resource_exists "compute_firewall" "$fw_rule" "$PROJECT_ID"; then
                # Determine the correct terraform resource name based on the firewall rule
                local tf_resource=""
                case "$fw_rule" in
                    *"internet-egress"*) tf_resource="google_compute_firewall.allow_internet_egress" ;;
                    *"egress-to-admin"*) tf_resource="google_compute_firewall.allow_egress_to_admin" ;;
                    *"allow-internal"*) tf_resource="google_compute_firewall.allow_internal" ;;
                    *"allow-from-admin"*) tf_resource="google_compute_firewall.allow_from_admin" ;;
                    *"block-inter-region"*) tf_resource="google_compute_firewall.block_inter_region" ;;
                esac

                if [[ -n "$tf_resource" ]]; then
                    import_resource \
                        "module.network[\"$region\"].$tf_resource" \
                        "projects/$PROJECT_ID/global/firewalls/$fw_rule" \
                        "Firewall Rule ($fw_rule)"
                fi
            fi
        done
    done
}

# Function to import GKE module resources
import_gke_modules() {
    print_section "Importing GKE Module Resources"

    for region in "${REGIONS[@]}"; do
        print_status "Importing GKE resources for region: $region"

        local cluster_name="${PROJECT_NAME}-gke-${region}"
        local node_pool_name="${PROJECT_NAME}-node-pool-${region}"

        # Import GKE cluster
        if resource_exists "container_cluster" "$cluster_name" "$PROJECT_ID" "$region"; then
            import_resource \
                "module.gke[\"$region\"].google_container_cluster.cluster" \
                "projects/$PROJECT_ID/locations/$region/clusters/$cluster_name" \
                "GKE Cluster ($region)"
        fi

        # Import node pool
        if resource_exists "container_node_pool" "$node_pool_name" "$PROJECT_ID" "$region" "" "$cluster_name"; then
            import_resource \
                "module.gke[\"$region\"].google_container_node_pool.primary" \
                "projects/$PROJECT_ID/locations/$region/clusters/$cluster_name/nodePools/$node_pool_name" \
                "GKE Node Pool ($region)"
        fi
    done
}

# Function to import bastion module resources
import_bastion_modules() {
    print_section "Importing Bastion Module Resources"

    for region in "${REGIONS[@]}"; do
        print_status "Importing bastion resources for region: $region"

        local bastion_name="${PROJECT_NAME}-bastion-${region}"
        local bastion_zone="${region}-a"  # Bastions typically use first zone
        local bastion_fw="${PROJECT_NAME}-bastion-ssh-from-admin-${region}"

        # Import bastion instance
        if resource_exists "compute_instance" "$bastion_name" "$PROJECT_ID" "" "$bastion_zone"; then
            import_resource \
                "module.bastion[\"$region\"].google_compute_instance.bastion" \
                "projects/$PROJECT_ID/zones/$bastion_zone/instances/$bastion_name" \
                "Bastion Instance ($region)"
        fi

        # Import bastion SSH firewall rule
        if resource_exists "compute_firewall" "$bastion_fw" "$PROJECT_ID"; then
            import_resource \
                "module.bastion[\"$region\"].google_compute_firewall.bastion_ssh_from_admin" \
                "projects/$PROJECT_ID/global/firewalls/$bastion_fw" \
                "Bastion SSH Firewall Rule ($region)"
        fi
    done
}

# Function to import storage module resources
import_storage_module() {
    print_section "Importing Storage Module Resources"

    # Import master bucket
    local master_bucket="${PROJECT_NAME}-content-master"
    if resource_exists "storage_bucket" "$master_bucket" "$PROJECT_ID"; then
        import_resource \
            "module.storage.google_storage_bucket.master" \
            "$master_bucket" \
            "Master Content Bucket"
    fi

#    # Import regional cache buckets - try both original and actual regions
#    for region in "${REGIONS[@]}"; do
#        local regional_bucket="${PROJECT_NAME}-content-${region}"
#        if resource_exists "storage_bucket" "$regional_bucket" "$PROJECT_ID"; then
#            import_resource \
#                "module.storage.google_storage_bucket.regional_cache[\"$region\"]" \
#                "$regional_bucket" \
#                "Regional Cache Bucket ($region)"
#        else
#            # Try common variations based on your error - europe-west4 vs europe-west2
#            local alt_region=""
#            case "$region" in
#                "europe-west2") alt_region="europe-west4" ;;
#                "europe-west4") alt_region="europe-west2" ;;
#            esac
#
#            if [[ -n "$alt_region" ]]; then
#                local alt_bucket="${PROJECT_NAME}-content-${alt_region}"
#                if resource_exists "storage_bucket" "$alt_bucket" "$PROJECT_ID"; then
#                    print_warning "Found bucket with different region name: $alt_bucket"
#                    import_resource \
#                        "module.storage.google_storage_bucket.regional_cache[\"$region\"]" \
#                        "$alt_bucket" \
#                        "Regional Cache Bucket ($region -> $alt_region)"
#                fi
#            fi
#        fi
#    done

    # Import service accounts
    local admin_sa="${PROJECT_NAME}-content-admin"
    local reader_sa="${PROJECT_NAME}-content-reader"

    if resource_exists "service_account" "$admin_sa" "$PROJECT_ID"; then
        import_resource \
            "module.storage.google_service_account.content_admin" \
            "projects/$PROJECT_ID/serviceAccounts/${admin_sa}@${PROJECT_ID}.iam.gserviceaccount.com" \
            "Content Admin Service Account"
    fi

    if resource_exists "service_account" "$reader_sa" "$PROJECT_ID"; then
        import_resource \
            "module.storage.google_service_account.content_reader" \
            "projects/$PROJECT_ID/serviceAccounts/${reader_sa}@${PROJECT_ID}.iam.gserviceaccount.com" \
            "Content Reader Service Account"
    fi

    # Import custom IAM role
    local custom_role="${PROJECT_NAME//-/_}_content_sync"
    if gcloud iam roles describe "$custom_role" --project="$PROJECT_ID" &>/dev/null; then
        import_resource \
            "module.storage.google_project_iam_custom_role.content_sync" \
            "projects/$PROJECT_ID/roles/$custom_role" \
            "Custom Content Sync Role"
    fi

    # Import service account keys if they exist
    print_status "Checking for service account keys..."

    # List keys for admin SA
    admin_key_id=$(gcloud iam service-accounts keys list --iam-account="${admin_sa}@${PROJECT_ID}.iam.gserviceaccount.com" --format="value(name)" --project="$PROJECT_ID" 2>/dev/null | grep -v "^$" | head -1)
    if [[ -n "$admin_key_id" ]]; then
        import_resource \
            "module.storage.google_service_account_key.content_admin_key" \
            "$admin_key_id" \
            "Content Admin Service Account Key"
    fi

    # List keys for reader SA
    reader_key_id=$(gcloud iam service-accounts keys list --iam-account="${reader_sa}@${PROJECT_ID}.iam.gserviceaccount.com" --format="value(name)" --project="$PROJECT_ID" 2>/dev/null | grep -v "^$" | head -1)
    if [[ -n "$reader_key_id" ]]; then
        import_resource \
            "module.storage.google_service_account_key.content_reader_key" \
            "$reader_key_id" \
            "Content Reader Service Account Key"
    fi

    print_warning "IAM bindings and policies may need to be recreated"
    print_warning "Run 'terraform plan' to see what needs to be added"
}

# Function to import load balancer module resources
import_loadbalancer_module() {
    print_section "Importing Load Balancer Module Resources"

    # Import global IP
    local global_ip="${PROJECT_NAME}-global-ip"
    if resource_exists "compute_global_address" "$global_ip" "$PROJECT_ID"; then
        import_resource \
            "module.loadbalancer.google_compute_global_address.lb_ip" \
            "projects/$PROJECT_ID/global/addresses/$global_ip" \
            "Global Load Balancer IP"
    fi

    # Import DNS zone (if domain is configured)
    local dns_zone="${PROJECT_NAME}-zone"
    if resource_exists "dns_managed_zone" "$dns_zone" "$PROJECT_ID"; then
        import_resource \
            "module.loadbalancer.google_dns_managed_zone.default[0]" \
            "projects/$PROJECT_ID/managedZones/$dns_zone" \
            "DNS Managed Zone"
    fi

    # Import SSL certificate
    local ssl_cert="${PROJECT_NAME}-managed-ssl-cert"
    if resource_exists "compute_ssl_certificate" "$ssl_cert" "$PROJECT_ID"; then
        import_resource \
            "module.loadbalancer.google_compute_managed_ssl_certificate.default[0]" \
            "projects/$PROJECT_ID/global/sslCertificates/$ssl_cert" \
            "Managed SSL Certificate"
    fi

    # Import health check
    local health_check="${PROJECT_NAME}-health-check"
    if gcloud compute health-checks describe "$health_check" --global --project="$PROJECT_ID" &>/dev/null; then
        import_resource \
            "module.loadbalancer.google_compute_health_check.default" \
            "projects/$PROJECT_ID/global/healthChecks/$health_check" \
            "Health Check"
    fi

    # Import backend service
    local backend_service="${PROJECT_NAME}-backend-service"
    if gcloud compute backend-services describe "$backend_service" --global --project="$PROJECT_ID" &>/dev/null; then
        import_resource \
            "module.loadbalancer.google_compute_backend_service.default" \
            "projects/$PROJECT_ID/global/backendServices/$backend_service" \
            "Backend Service"
    fi

    # Import URL map
    local url_map="${PROJECT_NAME}-url-map"
    if gcloud compute url-maps describe "$url_map" --global --project="$PROJECT_ID" &>/dev/null; then
        import_resource \
            "module.loadbalancer.google_compute_url_map.default" \
            "projects/$PROJECT_ID/global/urlMaps/$url_map" \
            "URL Map"
    fi

    # Import target proxies
    local http_proxy="${PROJECT_NAME}-http-proxy"
    local https_proxy="${PROJECT_NAME}-https-proxy"

    if gcloud compute target-http-proxies describe "$http_proxy" --global --project="$PROJECT_ID" &>/dev/null; then
        import_resource \
            "module.loadbalancer.google_compute_target_http_proxy.default" \
            "projects/$PROJECT_ID/global/targetHttpProxies/$http_proxy" \
            "HTTP Target Proxy"
    fi

    if gcloud compute target-https-proxies describe "$https_proxy" --global --project="$PROJECT_ID" &>/dev/null; then
        import_resource \
            "module.loadbalancer.google_compute_target_https_proxy.default[0]" \
            "projects/$PROJECT_ID/global/targetHttpsProxies/$https_proxy" \
            "HTTPS Target Proxy"
    fi

    # Import forwarding rules
    local http_rule="${PROJECT_NAME}-http-lb-rule"
    local https_rule="${PROJECT_NAME}-https-lb-rule"

    if gcloud compute forwarding-rules describe "$http_rule" --global --project="$PROJECT_ID" &>/dev/null; then
        import_resource \
            "module.loadbalancer.google_compute_global_forwarding_rule.http" \
            "projects/$PROJECT_ID/global/forwardingRules/$http_rule" \
            "HTTP Forwarding Rule"
    fi

    if gcloud compute forwarding-rules describe "$https_rule" --global --project="$PROJECT_ID" &>/dev/null; then
        import_resource \
            "module.loadbalancer.google_compute_global_forwarding_rule.https[0]" \
            "projects/$PROJECT_ID/global/forwardingRules/$https_rule" \
            "HTTPS Forwarding Rule"
    fi
}

# Function to import VPC peering connections
import_vpc_peering() {
    print_section "Importing VPC Peering Connections"

    for i in "${!REGIONS[@]}"; do
        local region="${REGIONS[$i]}"
        local region_num=$((i + 1))

        local admin_to_region="${PROJECT_NAME}-admin-to-region-${region_num}"
        local region_to_admin="${PROJECT_NAME}-region-${region_num}-to-admin"

        # Check and import admin-to-region peering
        if resource_exists "compute_network_peering" "$admin_to_region" "$PROJECT_ID" "" "" "${PROJECT_NAME}-admin-vpc"; then
            import_resource \
                "google_compute_network_peering.admin_to_region[\"$region\"]" \
                "projects/$PROJECT_ID/global/networks/${PROJECT_NAME}-admin-vpc/$admin_to_region" \
                "Admin to Region Peering ($region)"
        fi

        # Check and import region-to-admin peering
        if resource_exists "compute_network_peering" "$region_to_admin" "$PROJECT_ID" "" "" "${PROJECT_NAME}-vpc-${region}"; then
            import_resource \
                "google_compute_network_peering.region_to_admin[\"$region\"]" \
                "projects/$PROJECT_ID/global/networks/${PROJECT_NAME}-vpc-${region}/$region_to_admin" \
                "Region to Admin Peering ($region)"
        fi
    done
}

# Function to import API enablement resources
import_project_services() {
    print_section "Importing Project Service APIs"

    local apis=(
        "compute.googleapis.com"
        "container.googleapis.com"
        "storage.googleapis.com"
        "iam.googleapis.com"
        "dns.googleapis.com"
    )

    for api in "${apis[@]}"; do
        if gcloud services list --enabled --format="value(name)" --project="$PROJECT_ID" | grep -q "^$api$"; then
            print_status "API $api is enabled, but project services are usually not imported"
            print_warning "Consider removing google_project_service resources and using depends_on instead"
        fi
    done
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "terraform is not installed"
        exit 1
    fi

    # Check if gcloud is installed and authenticated
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed"
        exit 1
    fi

    # Check if authenticated to gcloud
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 &> /dev/null; then
        print_error "gcloud is not authenticated. Run 'gcloud auth login'"
        exit 1
    fi

    # Check if gsutil is available
    if ! command -v gsutil &> /dev/null; then
        print_error "gsutil is not available"
        exit 1
    fi

    # Check if terraform directory exists
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        print_error "Terraform directory '$TERRAFORM_DIR' not found"
        exit 1
    fi

    print_status "✅ All prerequisites met"
}

# Function to initialize terraform
initialize_terraform() {
    print_status "Initializing Terraform..."

    cd "$TERRAFORM_DIR"

    if terraform init; then
        print_status "✅ Terraform initialized successfully"
    else
        print_error "❌ Terraform initialization failed"
        exit 1
    fi

    cd - >/dev/null
}

# Function to show summary
show_summary() {
    print_section "Import Summary"

    local total_imported=0
    local total_failed=0

    # Count results from log
    total_imported=$(grep -c "Successfully imported" "$IMPORT_LOG" || echo "0")
    total_failed=$(grep -c "Failed to import" "$IMPORT_LOG" || echo "0")

    print_status "Import completed!"
    print_status "  Successfully imported: $total_imported resources"
    if [[ $total_failed -gt 0 ]]; then
        print_warning "  Failed to import: $total_failed resources"
    fi
    print_status "  Log file: $IMPORT_LOG"

    echo
    print_status "Next steps:"
    print_status "  1. Review the import log: $IMPORT_LOG"
    print_status "  2. Run 'terraform plan' to see any remaining changes"
    print_status "  3. Run 'terraform apply' if needed to sync remaining resources"
    print_status "  4. Consider running './generate-ansible-vars.sh' to update Ansible variables"
}

# Function to show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Import all existing GCP infrastructure into Terraform state.

OPTIONS:
    -d, --dry-run          Show what would be imported without actually importing
    -v, --verbose          Show detailed output for each import operation
    -c, --continue         Continue importing even if some resources fail
    -h, --help             Show this help message

EXAMPLES:
    # Dry run to see what would be imported
    $0 --dry-run

    # Import with verbose output
    $0 --verbose

    # Import and continue on errors
    $0 --continue

    # Full import (default)
    $0

PREREQUISITES:
    - terraform CLI installed and terraform directory exists
    - gcloud CLI installed and authenticated
    - gsutil available
    - terraform.tfvars configured with project details

NOTES:
    - This script imports infrastructure based on terraform.tfvars configuration
    - Some resources like IAM bindings may need to be recreated
    - Always run 'terraform plan' after importing to verify state
    - Back up any existing terraform.tfstate before running
EOF
}

# Main function
main() {
    print_header

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -c|--continue)
                CONTINUE_ON_ERROR=true
                shift
                ;;
            -h|--help)
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

    # Start import log
    echo "Terraform Import Log - $(date)" > "$IMPORT_LOG"
    echo "Project ID: $PROJECT_ID" >> "$IMPORT_LOG"
    echo "Project Name: $PROJECT_NAME" >> "$IMPORT_LOG"
    echo "Regions: ${REGIONS[*]}" >> "$IMPORT_LOG"
    echo "Dry Run: $DRY_RUN" >> "$IMPORT_LOG"
    echo "Continue on Error: $CONTINUE_ON_ERROR" >> "$IMPORT_LOG"
    echo "=====================================\n" >> "$IMPORT_LOG"

    # Check prerequisites
    check_prerequisites

    # Load configuration
    load_terraform_config

    # Initialize terraform
    initialize_terraform

    # Change to terraform directory for all imports
    cd "$TERRAFORM_DIR"

    # Import all modules in order
    import_project_services
    import_admin_module
    import_network_modules
    import_gke_modules
    import_bastion_modules
    import_storage_module
    import_loadbalancer_module
    import_vpc_peering

    # Return to original directory
    cd - >/dev/null

    # Show summary
    show_summary

    if [[ "$DRY_RUN" == true ]]; then
        print_status "Dry run completed. No resources were actually imported."
        print_status "Remove --dry-run flag to perform actual import."
    fi
}

# Run main function
main "$@"