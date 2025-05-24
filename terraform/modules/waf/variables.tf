variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "project_name" {
  description = "The name of the project, used for naming resources"
  type        = string
}

variable "name" {
  description = "Name for the Cloud Armor security policy"
  type        = string
  default     = "waf-security-policy"
}

variable "description" {
  description = "Description for the Cloud Armor security policy"
  type        = string
  default     = "WAF security policy to protect against common web attacks and block unwanted IPs"
}

variable "default_rule_action" {
  description = "Default action for the security policy (allow or deny)"
  type        = string
  default     = "allow"
}

variable "blocked_ips" {
  description = "List of IP addresses or ranges to block"
  type        = list(string)
  default     = []
}

variable "enable_xss_protection" {
  description = "Enable protection against XSS attacks"
  type        = bool
  default     = true
}

variable "enable_sqli_protection" {
  description = "Enable protection against SQL injection attacks"
  type        = bool
  default     = true
}

variable "enable_rce_protection" {
  description = "Enable protection against remote code execution attacks"
  type        = bool
  default     = true
}

variable "enable_lfi_protection" {
  description = "Enable protection against local file inclusion attacks"
  type        = bool
  default     = true
}

variable "enable_protocol_attack_protection" {
  description = "Enable protection against protocol attacks"
  type        = bool
  default     = true
}

variable "enable_scanner_protection" {
  description = "Enable protection against scanners and crawlers"
  type        = bool
  default     = true
}

variable "rate_limit_threshold" {
  description = "Threshold for rate limiting (requests per minute)"
  type        = number
  default     = 100
}

variable "enable_rate_limiting" {
  description = "Enable rate limiting for the security policy"
  type        = bool
  default     = true
}

variable "geo_restriction_regions" {
  description = "List of regions to restrict access from (ISO 3166-1 alpha-2 country codes)"
  type        = list(string)
  default     = []
}

variable "enable_geo_restriction" {
  description = "Enable geographic restrictions"
  type        = bool
  default     = false
}
