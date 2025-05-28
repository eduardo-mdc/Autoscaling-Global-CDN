# terraform/modules/loadbalancer/main.tf - Simplified Load Balancer

# Enable required APIs
resource "google_project_service" "compute_api" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "dns_api" {
  service            = "dns.googleapis.com"
  disable_on_destroy = false
}

# Create global static IP FIRST (independent)
resource "google_compute_global_address" "lb_ip" {
  name         = "${var.project_name}-global-ip"
  description  = "Global IP for ${var.project_name} load balancer"
  ip_version   = "IPV4"
  address_type = "EXTERNAL"

  depends_on = [google_project_service.compute_api]
}

# DNS Zone (only if domain provided)
resource "google_dns_managed_zone" "default" {
  count = var.domain_name != "" ? 1 : 0

  name        = "${var.project_name}-zone"
  dns_name    = "${var.domain_name}."
  description = "DNS zone for ${var.project_name}"
  visibility  = "public"

  # Enable DNSSEC for security
  dnssec_config {
    state         = "on"
    non_existence = "nsec3"
  }

  depends_on = [google_project_service.dns_api]
}

# A record for root domain
resource "google_dns_record_set" "root" {
  count = var.domain_name != "" ? 1 : 0

  name         = "${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.default[0].name
  rrdatas      = [google_compute_global_address.lb_ip.address]
}

# A record for www subdomain
resource "google_dns_record_set" "www" {
  count = var.domain_name != "" ? 1 : 0

  name         = "www.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.default[0].name
  rrdatas      = [google_compute_global_address.lb_ip.address]
}

# Health check for backend services
resource "google_compute_health_check" "default" {
  name               = "${var.project_name}-health-check"
  description        = "Health check for streaming servers"
  timeout_sec        = 5
  check_interval_sec = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/health"
  }
}

# Backend service with location-based balancing - SIMPLIFIED
resource "google_compute_backend_service" "default" {
  name                  = "${var.project_name}-backend-service"
  description          = "Backend service for streaming servers"
  protocol             = "HTTP"
  port_name            = "http"
  timeout_sec          = 60
  load_balancing_scheme = "EXTERNAL"

  health_checks = [google_compute_health_check.default.id]

  # Connection draining
  connection_draining_timeout_sec = 60

  # Enable logging
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL map with simple default service (GCP handles geo-routing automatically)
resource "google_compute_url_map" "default" {
  name            = "${var.project_name}-url-map"
  description     = "URL map for ${var.project_name} with automatic geo-based routing"
  default_service = google_compute_backend_service.default.id
}

# HTTP Target Proxy
resource "google_compute_target_http_proxy" "default" {
  name    = "${var.project_name}-http-proxy"
  url_map = google_compute_url_map.default.id
}

# HTTP Global Forwarding Rule (simplified)
resource "google_compute_global_forwarding_rule" "http" {
  name       = "${var.project_name}-http-rule"
  target     = google_compute_target_http_proxy.default.id
  port_range = "80"
  ip_address = google_compute_global_address.lb_ip.address
}

# ============================================================================
# SSL CONFIGURATION (Only if domain is provided)
# ============================================================================

# Google-managed SSL certificate - SIMPLIFIED (no timing dependencies)
resource "google_compute_managed_ssl_certificate" "default" {
  count = var.domain_name != "" ? 1 : 0

  name = "${var.project_name}-ssl-cert"

  managed {
    domains = [
      var.domain_name,
      "www.${var.domain_name}"
    ]
  }

  lifecycle {
    create_before_destroy = true
  }

  timeouts {
    create = "30m"
    delete = "10m"
  }
}

# Modern SSL policy
resource "google_compute_ssl_policy" "modern" {
  count = var.domain_name != "" ? 1 : 0

  name            = "${var.project_name}-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

# HTTPS Target Proxy (simplified)
resource "google_compute_target_https_proxy" "default" {
  count = var.domain_name != "" ? 1 : 0

  name             = "${var.project_name}-https-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default[0].id]
}

# HTTPS Global Forwarding Rule (simplified)
resource "google_compute_global_forwarding_rule" "https" {
  count = var.domain_name != "" ? 1 : 0

  name       = "${var.project_name}-https-rule"
  target     = google_compute_target_https_proxy.default[0].id
  port_range = "443"
  ip_address = google_compute_global_address.lb_ip.address
}

# CAA records for certificate security
resource "google_dns_record_set" "caa" {
  count = var.domain_name != "" && var.enable_caa_records ? 1 : 0

  name         = "${var.domain_name}."
  type         = "CAA"
  ttl          = 3600
  managed_zone = google_dns_managed_zone.default[0].name

  rrdatas = [
    "0 issue \"pki.goog\"",
    "0 issue \"letsencrypt.org\"",
    "0 iodef \"mailto:admin@${var.domain_name}\""
  ]
}