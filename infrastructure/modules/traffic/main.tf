
// Create resources only if domain_name is provided
locals {
  create_domain = var.domain_name != ""
}

// Domain resource (similar to Route53 zone)
resource "digitalocean_domain" "default" {
  count      = local.create_domain ? 1 : 0
  name       = var.domain_name
  ip_address = values(var.loadbalancer_ips)[0]  # Default to first region
}

// Create regional subdomains (eu.domain.com, us.domain.com, asia.domain.com)
resource "digitalocean_record" "regional" {
  for_each = local.create_domain ? toset(var.regions) : []

  domain = digitalocean_domain.default[0].name
  type   = "A"
  name   = each.key
  value  = var.loadbalancer_ips[each.key]
  ttl    = 60
}