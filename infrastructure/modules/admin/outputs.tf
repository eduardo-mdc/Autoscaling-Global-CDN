output "admin_public_ip" {
  description = "Public IP of the admin droplet"
  value       = digitalocean_reserved_ip.admin_ip.ip_address
}

output "admin_droplet_id" {
  description = "ID of the admin droplet"
  value       = digitalocean_droplet.admin.id
}

output "admin_key_fingerprint" {
  description = "Fingerprint of the SSH key for the admin host"
  value       = local.key_fingerprint
}

output "admin_firewall_id" {
  description = "Firewall ID for the admin host"
  value       = digitalocean_firewall.admin_fw.id
}