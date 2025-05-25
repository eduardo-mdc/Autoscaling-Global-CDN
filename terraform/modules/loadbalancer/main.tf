# Global HTTP Load Balancer module for GKE services with integrated domain management

# Enable required APIs
resource "google_project_service" "compute_api" {
  service = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "dns_api" {
  service = "dns.googleapis.com"
  disable_on_destroy = false
}

# Create global static IP
resource "google_compute_global_address" "lb_ip" {
  name = "${var.project_name}-global-ip"
}

# DNS Zone and Records (if domain provided)
resource "google_dns_managed_zone" "default" {
  count = var.domain_name != "" ? 1 : 0

  name        = "${var.project_name}-zone"
  dns_name    = "${var.domain_name}."
  description = "DNS zone for ${var.project_name} - ${var.domain_name}"

  visibility = "public"

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

  rrdatas = [google_compute_global_address.lb_ip.address]
}

# A record for www subdomain
resource "google_dns_record_set" "www" {
  count = var.domain_name != "" ? 1 : 0

  name         = "www.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.default[0].name

  rrdatas = [google_compute_global_address.lb_ip.address]
}

# Optional A records for regional subdomains
resource "google_dns_record_set" "regional" {
  for_each = var.domain_name != "" && var.enable_regional_subdomains ? toset(var.regions) : []

  name         = "${each.key}.${var.domain_name}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.default[0].name

  rrdatas = [google_compute_global_address.lb_ip.address]
}

# Google-managed SSL certificate
resource "google_compute_managed_ssl_certificate" "default" {
  count = var.domain_name != "" ? 1 : 0

  name = "${var.project_name}-managed-ssl-cert"

  managed {
    domains = concat(
      [var.domain_name, "www.${var.domain_name}"],
        var.enable_regional_subdomains ? [for region in var.regions : "${region}.${var.domain_name}"] : [],
      var.additional_domains
    )
  }

  lifecycle {
    create_before_destroy = true
  }

  timeouts {
    create = "60m"
    delete = "30m"
  }
}

# Modern SSL policy
resource "google_compute_ssl_policy" "modern" {
  count = var.domain_name != "" ? 1 : 0

  name            = "${var.project_name}-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

# CAA records for certificate authority authorization (optional but recommended)
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

# Create global health check (updated path)
resource "google_compute_health_check" "default" {
  name = "${var.project_name}-health-check"

  http_health_check {
    port         = 80
    request_path = "/health"  # Updated to match your streaming server
  }

  # More aggressive checking for demo purposes
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# Create backend service that points to GKE ingress in each region
resource "google_compute_backend_service" "default" {
  name                  = "${var.project_name}-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 60
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.default.id]

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
  ]

  # Connection draining
  connection_draining_timeout_sec = 60

  # Enable logging
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# Create URL map for load balancer
resource "google_compute_url_map" "default" {
  name            = "${var.project_name}-url-map"
  default_service = google_compute_backend_service.default.id

  # Optional: Configure host rules for regional routing if needed
  dynamic "host_rule" {
    for_each = var.domain_name != "" && var.enable_regional_subdomains ? var.regions : []

    content {
      hosts        = ["${host_rule.value}.${var.domain_name}"]
      path_matcher = "region-${host_rule.value}"
    }
  }

  # Optional: Configure path matchers for regional routing if needed
  dynamic "path_matcher" {
    for_each = var.domain_name != "" && var.enable_regional_subdomains ? var.regions : []

    content {
      name            = "region-${path_matcher.value}"
      default_service = lookup(var.regional_backend_services, path_matcher.value, google_compute_backend_service.default.id)
    }
  }
}

# HTTP Target Proxy
resource "google_compute_target_http_proxy" "default" {
  name    = "${var.project_name}-http-proxy"
  url_map = google_compute_url_map.default.id
}

# HTTPS Target Proxy (only one definition)
resource "google_compute_target_https_proxy" "default" {
  count   = var.domain_name != "" ? 1 : 0
  name    = "${var.project_name}-https-proxy"
  url_map = google_compute_url_map.default.id

  ssl_certificates = [google_compute_managed_ssl_certificate.default[0].id]
  ssl_policy      = google_compute_ssl_policy.modern[0].id

  # Enable QUIC for better performance
  quic_override = "ENABLE"
}

# HTTP Global Forwarding Rule
resource "google_compute_global_forwarding_rule" "http" {
  name       = "${var.project_name}-http-lb-rule"
  target     = google_compute_target_http_proxy.default.id
  port_range = "80"
  ip_address = google_compute_global_address.lb_ip.address

  labels = {
    environment = "production"
    service     = "streaming"
  }
}

# HTTPS Global Forwarding Rule
resource "google_compute_global_forwarding_rule" "https" {
  count      = var.domain_name != "" ? 1 : 0
  name       = "${var.project_name}-https-lb-rule"
  target     = google_compute_target_https_proxy.default[0].id
  port_range = "443"
  ip_address = google_compute_global_address.lb_ip.address

  labels = {
    environment = "production"
    service     = "streaming"
    ssl_type    = "managed"
  }
}