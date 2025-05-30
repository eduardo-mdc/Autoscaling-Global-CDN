output "security_policy_id" {
  description = "The ID of the created Cloud Armor security policy"
  value       = google_compute_security_policy.policy.id
}

output "security_policy_name" {
  description = "The name of the created Cloud Armor security policy"
  value       = google_compute_security_policy.policy.name
}

output "security_policy_self_link" {
  description = "The self link of the created Cloud Armor security policy"
  value       = google_compute_security_policy.policy.self_link
}

output "security_policy_fingerprint" {
  description = "The fingerprint of the created Cloud Armor security policy"
  value       = google_compute_security_policy.policy.fingerprint
}

output "rule_tuples" {
  description = "List of rule priority and description tuples for the security policy"
  value = [
    for rule in google_compute_security_policy.policy.rule : {
      priority    = rule.priority
      description = rule.description
      action      = rule.action
    }
  ]
}
