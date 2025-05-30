variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "project_name" {
  description = "The name of the project, used for naming resources"
  type        = string
}

variable "domain_name" {
  description = "The domain name for which to create a managed zone"
  type        = string
}

variable "description" {
  description = "Description for the DNS managed zone"
  type        = string
  default     = "Managed DNS zone for the project"
}

variable "dns_name" {
  description = "DNS name of the zone, if different from domain_name (must end with a period)"
  type        = string
  default     = ""
}

variable "ttl" {
  description = "Time-to-live for DNS records in seconds"
  type        = number
  default     = 300
}

variable "load_balancer_ip" {
  description = "IP address of the load balancer for the main domain A record"
  type        = string
}

variable "grafana_vm_ip" {
  description = "IP address of the Grafana VM for the grafana subdomain A record"
  type        = string
}

variable "enable_dnssec" {
  description = "Enable DNSSEC for the managed zone"
  type        = bool
  default     = true
}

variable "labels" {
  description = "A map of labels to apply to the DNS zone"
  type        = map(string)
  default     = {}
}

variable "private_visibility_config" {
  description = "Configuration for private DNS zone visibility"
  type        = list(object({
    network_url = string
  }))
  default     = []
}

variable "is_private_zone" {
  description = "Whether this is a private DNS zone"
  type        = bool
  default     = false
}
