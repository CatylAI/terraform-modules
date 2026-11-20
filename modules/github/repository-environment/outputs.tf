output "environment_name" {
  description = "The environment's name, for a workflow's `environment:` key. Null when the module is disabled."
  value       = one(github_repository_environment.this[*].environment)
}
