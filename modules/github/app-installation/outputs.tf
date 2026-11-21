output "repositories" {
  description = "Names of the repositories this module attaches to the installation. Repositories attached outside this module are not listed. Null when the module is disabled."
  value       = var.enabled ? toset([for r in github_app_installation_repository.this : r.repository]) : null
}
