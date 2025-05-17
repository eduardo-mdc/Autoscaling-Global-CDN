variable "project_name" {
  type        = string
  description = "Prefix for resource names"
}

variable "domain_name" {
  type        = string
  description = "Domain name to use for traffic management"
  default     = ""  # Optional - if not provided, will not create domain records
}

variable "loadbalancer_ips" {
  type        = map(string)
  description = "Map of region names to load balancer IPs"
}

variable "regions" {
  type        = list(string)
  description = "List of region names"
}