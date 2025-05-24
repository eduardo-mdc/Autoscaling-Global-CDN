# Google Cloud Armor WAF Module
# Creates a security policy with rules to block unwanted IPs and protect against common web attacks

# Create the Cloud Armor security policy
resource "google_compute_security_policy" "policy" {
  name        = var.name
  description = var.description
  
  # Default rule (applied last)
  rule {
    action   = var.default_rule_action
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule, ${var.default_rule_action} all traffic"
  }

  # Block specific IPs if provided
  dynamic "rule" {
    for_each = length(var.blocked_ips) > 0 ? [1] : []
    content {
      action   = "deny(403)"
      priority = 1000
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = var.blocked_ips
        }
      }
      description = "Block specified IP addresses"
    }
  }

  # Geographic restrictions if enabled
  dynamic "rule" {
    for_each = var.enable_geo_restriction && length(var.geo_restriction_regions) > 0 ? [1] : []
    content {
      action   = "deny(403)"
      priority = 1001
      match {
        expr {
          expression = join(" || ", [for region in var.geo_restriction_regions : "origin.region_code == '${region}'"])
        }
      }
      description = "Block traffic from restricted regions"
    }
  }

  # XSS Protection
  dynamic "rule" {
    for_each = var.enable_xss_protection ? [1] : []
    content {
      action   = "deny(403)"
      priority = 1002
      match {
        expr {
          expression = "evaluatePreconfiguredExpr('xss-stable')"
        }
      }
      description = "XSS protection"
    }
  }

  # SQL Injection Protection
  dynamic "rule" {
    for_each = var.enable_sqli_protection ? [1] : []
    content {
      action   = "deny(403)"
      priority = 1003
      match {
        expr {
          expression = "evaluatePreconfiguredExpr('sqli-stable')"
        }
      }
      description = "SQL injection protection"
    }
  }

  # Remote Code Execution Protection
  dynamic "rule" {
    for_each = var.enable_rce_protection ? [1] : []
    content {
      action   = "deny(403)"
      priority = 1004
      match {
        expr {
          expression = "evaluatePreconfiguredExpr('rce-stable')"
        }
      }
      description = "Remote code execution protection"
    }
  }

  # Local File Inclusion Protection
  dynamic "rule" {
    for_each = var.enable_lfi_protection ? [1] : []
    content {
      action   = "deny(403)"
      priority = 1005
      match {
        expr {
          expression = "evaluatePreconfiguredExpr('lfi-stable')"
        }
      }
      description = "Local file inclusion protection"
    }
  }

  # Protocol Attack Protection
  dynamic "rule" {
    for_each = var.enable_protocol_attack_protection ? [1] : []
    content {
      action   = "deny(403)"
      priority = 1006
      match {
        expr {
          expression = "evaluatePreconfiguredExpr('protocol-attack-stable')"
        }
      }
      description = "Protocol attack protection"
    }
  }

  # Scanner/Crawler Protection
  dynamic "rule" {
    for_each = var.enable_scanner_protection ? [1] : []
    content {
      action   = "deny(403)"
      priority = 1007
      match {
        expr {
          expression = "evaluatePreconfiguredExpr('scanners-stable')"
        }
      }
      description = "Scanner and crawler protection"
    }
  }

  # Rate Limiting
  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      action   = "rate_based_ban"
      priority = 1008
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = ["*"]
        }
      }
      description = "Rate limiting protection"
      rate_limit_options {
        conform_action = "allow"
        exceed_action  = "deny(429)"
        enforce_on_key = "IP"
        rate_limit_threshold {
          count        = var.rate_limit_threshold
          interval_sec = 60
        }
      }
    }
  }
}
