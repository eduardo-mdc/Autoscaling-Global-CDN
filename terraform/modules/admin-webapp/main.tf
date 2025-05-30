# Admin Webapp Module with Load Balancer and IAP
# Complete rewrite for VM-based Flask app with managed authentication

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "iap.googleapis.com",
    "dns.googleapis.com"
  ])

  service            = each.value
  disable_on_destroy = false
}

# Reserve global static IP for admin webapp
resource "google_compute_global_address" "admin_webapp_ip" {
  name        = "${var.project_name}-content-manager-ip"
  description = "Global IP for content-manager load balancer"

  depends_on = [google_project_service.required_apis]
}

# Health check for admin webapp
resource "google_compute_health_check" "admin_webapp" {
  name                = "${var.project_name}-admin-webapp-health"
  description         = "Health check for admin webapp"
  timeout_sec         = 5
  check_interval_sec  = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/health"
  }

  depends_on = [google_project_service.required_apis]
}

# Instance group for admin VM
resource "google_compute_instance_group" "admin_webapp" {
  name = "${var.project_name}-admin-webapp-group"
  zone = var.admin_vm_zone

  instances = [var.admin_vm_self_link]

  named_port {
    name = "http"
    port = 80
  }

  depends_on = [google_project_service.required_apis]
}

# Backend service with IAP enabled
resource "google_compute_backend_service" "admin_webapp" {
  name                  = "${var.project_name}-admin-webapp-backend"
  description          = "Backend service for admin webapp with IAP"
  protocol             = "HTTP"
  port_name            = "http"
  timeout_sec          = 60
  load_balancing_scheme = "EXTERNAL"

  backend {
    group           = google_compute_instance_group.admin_webapp.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.admin_webapp.id]

  # Enable IAP
  iap {
    oauth2_client_id     = var.oauth_client_id
    oauth2_client_secret = var.oauth_client_secret
  }

  # Connection draining
  connection_draining_timeout_sec = 60

  # Enable request/response logging
  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [google_project_service.required_apis]
}

# IAM binding for authorized users
resource "google_iap_web_backend_service_iam_binding" "admin_access" {
  web_backend_service = google_compute_backend_service.admin_webapp.name
  role                = "roles/iap.httpsResourceAccessor"
  members             = var.authorized_users

  depends_on = [google_compute_backend_service.admin_webapp]
}

# Managed SSL certificate
resource "google_compute_managed_ssl_certificate" "content_manager" {
  name = "${var.project_name}-admin-webapp-ssl"

  managed {
    domains = [var.admin_domain]
  }

  lifecycle {
    create_before_destroy = true
  }

  timeouts {
    create = "30m"
    delete = "10m"
  }

  depends_on = [google_project_service.required_apis]
}

# URL map
resource "google_compute_url_map" "admin_webapp" {
  name            = "${var.project_name}-admin-webapp-urlmap"
  description     = "URL map for admin webapp"
  default_service = google_compute_backend_service.admin_webapp.id

  depends_on = [google_compute_backend_service.admin_webapp]
}

# HTTPS target proxy
resource "google_compute_target_https_proxy" "admin_webapp" {
  name             = "${var.project_name}-admin-webapp-https-proxy"
  url_map          = google_compute_url_map.admin_webapp.id
  ssl_certificates = [google_compute_managed_ssl_certificate.content_manager.id]

  depends_on = [google_compute_managed_ssl_certificate.content_manager]
}

# HTTP to HTTPS redirect
resource "google_compute_target_http_proxy" "admin_webapp_redirect" {
  name    = "${var.project_name}-admin-webapp-http-proxy"
  url_map = google_compute_url_map.admin_webapp_redirect.id
}

resource "google_compute_url_map" "admin_webapp_redirect" {
  name = "${var.project_name}-admin-webapp-redirect-urlmap"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# Global forwarding rules
resource "google_compute_global_forwarding_rule" "admin_webapp_https" {
  name       = "${var.project_name}-admin-webapp-https-rule"
  target     = google_compute_target_https_proxy.admin_webapp.id
  port_range = "443"
  ip_address = google_compute_global_address.admin_webapp_ip.address

  labels = {
    service = "admin-webapp"
    ssl     = "managed"
  }

  depends_on = [google_compute_target_https_proxy.admin_webapp]
}

resource "google_compute_global_forwarding_rule" "admin_webapp_http" {
  name       = "${var.project_name}-admin-webapp-http-rule"
  target     = google_compute_target_http_proxy.admin_webapp_redirect.id
  port_range = "80"
  ip_address = google_compute_global_address.admin_webapp_ip.address

  labels = {
    service = "admin-webapp"
    redirect = "https"
  }

  depends_on = [google_compute_target_http_proxy.admin_webapp_redirect]
}

# DNS record for admin domain
resource "google_dns_record_set" "admin_webapp" {
  count = var.dns_zone_name != "" ? 1 : 0

  name         = "${var.admin_domain}."
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_zone_name
  rrdatas      = [google_compute_global_address.admin_webapp_ip.address]

  depends_on = [google_project_service.required_apis]
}

# Firewall rule to allow load balancer health checks
resource "google_compute_firewall" "admin_webapp_health_check" {
  name    = "${var.project_name}-admin-webapp-health-check"
  network = var.admin_vm_network

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # Google Cloud health check IP ranges
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]

  target_tags = ["admin-webapp"]
  priority    = 1000

  depends_on = [google_project_service.required_apis]
}