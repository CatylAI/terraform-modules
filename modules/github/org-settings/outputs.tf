output "organization_id" {
  description = "Numeric id of the organisation. Null when the module is disabled."
  value       = one(github_organization_settings.this[*].id)
}

output "organization" {
  description = "Login of the organisation the settings apply to: the github provider's owner. Null when the module is disabled."
  value       = one(github_actions_organization_workflow_permissions.this[*].organization_slug)
}
