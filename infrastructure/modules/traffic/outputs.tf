output "domain_name" {
  value = local.create_domain ? digitalocean_domain.default[0].name : null
}

output "regional_domains" {
  value = local.create_domain ? {
    for region in var.regions :
    region => "${region}.${var.domain_name}"
  } : {}
}

output "loadbalancer_ips" {
  value = var.loadbalancer_ips
}