# Global HTTP Load Balancer module for GKE services

# Enable required APIs
resource "google_project_service" "compute_api" {
  service = "compute.googleapis.com"
  disable_on_destroy = false
}

# Create global static IP
resource "google_compute_global_address" "lb_ip" {
  name = "${var.project_name}-global-ip"
}

# Create global health check
resource "google_compute_health_check" "default" {
  name = "${var.project_name}-health-check"

  http_health_check {
    port         = 80
    request_path = "/healthz"
  }

  # More aggressive checking for demo purposes
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2
}

# Create backend service that points to GKE ingress in each region
resource "google_compute_backend_service" "default" {
  name                  = "${var.project_name}-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.default.id]
  enable_cdn            = var.enable_cdn

  # Add all regional backends
  dynamic "backend" {
    for_each = var.backend_services

    content {
      group           = backend.value
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    }
  }

  # Custom request headers
  custom_request_headers = [
    "X-Client-Region: {client_region}",
    "X-Client-IP: {client_ip}"
  ]

  # If CDN is enabled, configure caching
  cdn_policy {
    cache_mode                   = var.enable_cdn ? "CACHE_ALL_STATIC" : "CACHE_DISABLED"
    client_ttl                   = var.enable_cdn ? 3600 : null
    default_ttl                  = var.enable_cdn ? 3600 : null
    max_ttl                      = var.enable_cdn ? 86400 : null
    negative_caching             = var.enable_cdn
    serve_while_stale            = var.enable_cdn ? 86400 : null
    signed_url_cache_max_age_sec = var.enable_cdn ? 7200 : null
  }
}

# Create URL map for load balancer
resource "google_compute_url_map" "default" {
  name            = "${var.project_name}-url-map"
  default_service = google_compute_backend_service.default.id

  # Optional: Configure host rules for regional routing if needed
  dynamic "host_rule" {
    for_each = var.domain_name != "" ? var.regions : []

    content {
      hosts        = ["${host_rule.value}.${var.domain_name}"]
      path_matcher = "region-${host_rule.value}"
    }
  }

  # Optional: Configure path matchers for regional routing if needed
  dynamic "path_matcher" {
    for_each = var.domain_name != "" ? var.regions : []

    content {
      name            = "region-${path_matcher.value}"
      default_service = var.regional_backend_services[path_matcher.value]
    }
  }
}

# HTTP Proxy
resource "google_compute_target_http_proxy" "default" {
  name    = "${var.project_name}-http-proxy"
  url_map = google_compute_url_map.default.id
}

# HTTPS Proxy (conditional on domain and cert)
resource "google_compute_target_https_proxy" "default" {
  count   = var.domain_name != "" && var.ssl_certificate != "" ? 1 : 0
  name    = "${var.project_name}-https-proxy"
  url_map = google_compute_url_map.default.id
  ssl_certificates = [var.ssl_certificate]
}

# HTTP Global Forwarding Rule
resource "google_compute_global_forwarding_rule" "http" {
  name       = "${var.project_name}-http-lb-rule"
  target     = google_compute_target_http_proxy.default.id
  port_range = "80"
  ip_address = google_compute_global_address.lb_ip.address
}

# HTTPS Global Forwarding Rule (conditional)
resource "google_compute_global_forwarding_rule" "https" {
  count      = var.domain_name != "" && var.ssl_certificate != "" ? 1 : 0
  name       = "${var.project_name}-https-lb-rule"
  target     = google_compute_target_https_proxy.default[0].id
  port_range = "443"
  ip_address = google_compute_global_address.lb_ip.address
}

# DNS zone and records (if domain provided)
resource "google_dns_managed_zone" "default" {
  count = var.domain_name != "" ? 1 : 0

  name        = "${var.project_name}-zone"
  dns_name    = "${var.domain_name}."
  description = "DNS zone for ${var.project_name}"
}

# A record for root domain
resource "google_dns_record_set" "root" {
  count = var.domain_name != "" ? 1 : 0

  name         = "${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.default[0].name

  rrdatas = [google_compute_global_address.lb_ip.address]
}

# A records for regional subdomains
resource "google_dns_record_set" "regional" {
  for_each = var.domain_name != "" ? toset(var.regions) : []

  name         = "${each.key}.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.default[0].name

  rrdatas = [google_compute_global_address.lb_ip.address]
}