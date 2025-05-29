output "ssh_key_debug" {
  description = "Debug output to verify SSH key content"
  value       = "${substr(file(var.ssh_public_key_path), 0, 50)}..."
  sensitive   = true
}

output "admin_public_ip" {
  description = "Public IP of the admin VM"
  value       = module.admin.admin_public_ip
}

output "admin_ssh_command" {
  description = "SSH command to connect to admin VM"
  value       = "ssh ${var.admin_username}@${module.admin.admin_public_ip}"
}

output "gke_clusters" {
  description = "Map of GKE cluster details by region and type (hot/cold)"
  value = merge(
    {
      for region in var.hot_regions :
      "${region} (hot)" => {
        cluster_name = module.gke_hot[region].cluster_name
        endpoint     = module.gke_hot[region].cluster_endpoint
        type         = "hot"
      }
    },
    {
      for region in var.cold_regions :
      "${region} (cold)" => {
        cluster_name = module.gke_cold[region].cluster_name
        endpoint     = module.gke_cold[region].cluster_endpoint
        type         = "cold"
      }
    }
  )
}

output "gke_connect_commands" {
  description = "Commands to connect to each GKE cluster from admin VM"
  value = merge(
    {
      for region in var.hot_regions :
      "${region} (hot)" =>
      "gcloud container clusters get-credentials ${module.gke_hot[region].cluster_name} --region ${region} --project ${var.project_id}"
    },
    {
      for region in var.cold_regions :
      "${region} (cold)" =>
      "gcloud container clusters get-credentials ${module.gke_cold[region].cluster_name} --region ${region} --project ${var.project_id}"
    }
  )
}

output "load_balancer_ip" {
  description = "Global IP address of the load balancer"
  value       = module.loadbalancer.load_balancer_ip
}

output "network_details" {
  description = "VPC network details by region"
  value = {
    for region in var.regions :
    region => {
      network_name = module.network[region].network_name
      subnet_cidr  = module.network[region].subnet_cidr
    }
  }
}

# Add these outputs to your main outputs.tf

output "bastion_internal_ips" {
  description = "Internal IP addresses of bastion hosts"
  value = {
    for region in var.regions :
    region => module.bastion[region].bastion_internal_ip
  }
}

output "bastion_ssh_via_admin" {
  description = "SSH commands to connect to bastion hosts via admin VM"
  value = {
    for region in var.regions :
    region => "ssh -J ${var.admin_username}@${module.admin.admin_public_ip} ${var.admin_username}@${module.bastion[region].bastion_internal_ip}"
  }
}

output "domain_configuration" {
  description = "Domain and SSL configuration"
  value = {
    domain_name           = module.loadbalancer.domain_name
    nameservers          = module.loadbalancer.dns_zone_nameservers
    ssl_certificate_name = module.loadbalancer.ssl_certificate_name
    ssl_domains         = module.loadbalancer.ssl_certificate_domains
  }
}




output "kubectl_access_via_bastions" {
  description = "Instructions for accessing GKE clusters via bastion hosts"
  value = {
    for region in var.regions :
    region => "Connect via: ssh -J ${var.admin_username}@${module.admin.admin_public_ip} ${var.admin_username}@${module.bastion[region].bastion_internal_ip}"
  }
}

# Storage Outputs
output "storage_summary" {
  description = "Summary of all storage resources created"
  value       = module.storage.storage_summary
}

output "master_bucket_name" {
  description = "Name of the master content bucket"
  value       = module.storage.master_bucket_name
}

output "regional_bucket_names" {
  description = "Map of region to regional cache bucket names"
  value       = module.storage.regional_bucket_names
}

output "content_admin_sa_email" {
  description = "Email of the content admin service account"
  value       = module.storage.content_admin_sa_email
}

output "content_reader_sa_email" {
  description = "Email of the content reader service account"
  value       = module.storage.content_reader_sa_email
}

output "gsutil_sync_commands" {
  description = "Example gsutil commands for content synchronization"
  value       = module.storage.gsutil_sync_commands
}

output "workload_identity_annotation" {
  description = "Annotation to add to Kubernetes service account for Workload Identity"
  value       = module.storage.workload_identity_annotation
}

output "csi_driver_config" {
  description = "Configuration for GCS FUSE CSI driver per region"
  value       = module.storage.csi_driver_config
}

# Content Management Instructions
output "content_management_instructions" {
  description = "Instructions for content upload and management"
  value = {
    upload_directory = "/opt/content/uploads/"
    master_bucket   = module.storage.master_bucket_name
    regional_buckets = module.storage.regional_bucket_names
    sync_commands = {
      to_master = "gsutil -m rsync -r -d /opt/content/uploads/ gs://${module.storage.master_bucket_name}/"
      to_regions = {
        for region in var.regions :
        region => "gsutil -m rsync -r -d gs://${module.storage.master_bucket_name}/ gs://${module.storage.regional_bucket_names[region]}/"
      }
    }
    service_accounts = {
      admin_sa  = module.storage.content_admin_sa_email
      reader_sa = module.storage.content_reader_sa_email
    }
  }
}

output "gcs_csi_enabled" {
  description = "GCS CSI driver enablement status per cluster"
  value = {
    for region in var.regions :
    region => "enabled"
  }
}

output "workload_identity_pool" {
  description = "Workload Identity pool for the project"
  value       = "${var.project_id}.svc.id.goog"
}


# Replace load_balancer_ip with MCI IP
output "mci_global_ip" {
  description = "Global IP for Multi-Cluster Ingress"
  value       = module.fleet.mci_global_ip
}

# Replace deployment_urls
output "deployment_urls" {
  description = "URLs to access your deployment via MCI"
  value       = module.fleet.deployment_urls
}

# Replace nameserver_instructions
output "nameserver_instructions" {
  description = "Instructions for configuring nameservers"
  value = var.domain_name != "" ? {
    message = "Configure these nameservers at your domain registrar:"
    nameservers = module.fleet.dns_zone_nameservers
    domain = var.domain_name
  } : null
}

output "fleet_summary" {
  description = "GKE Fleet configuration summary"
  value = {
    config_cluster       = var.hot_regions[0]
    member_clusters      = slice(var.hot_regions, 1, length(var.hot_regions))
    mci_global_ip        = module.fleet.mci_global_ip
    mci_global_ip_name   = module.fleet.mci_global_ip_name
  }
}

# Remove or comment out old loadbalancer outputs:
# output "load_balancer_ip" { ... }
# output "domain_configuration" { ... }