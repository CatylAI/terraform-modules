output "organization_id" {
  description = "Numeric id of the organisation."
  value       = module.org_settings.organization_id
}

output "organization" {
  description = "Login of the organisation the settings apply to."
  value       = module.org_settings.organization
}
