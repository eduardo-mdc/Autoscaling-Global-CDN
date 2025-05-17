output "vpc_id" {
  value = data.digitalocean_vpc.default.id
}

output "vpc_name" {
  value = data.digitalocean_vpc.default.name
}

output "region" {
  value = var.region
}

output "web_firewall_id" {
  value = digitalocean_firewall.web.id
}