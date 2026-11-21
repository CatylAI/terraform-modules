output "full_name" {
  description = "Repository full name, <owner>/<name>."
  value       = module.repository.full_name
}

output "node_id" {
  description = "GraphQL node id of the repository."
  value       = module.repository.node_id
}

output "default_branch" {
  description = "Default branch name."
  value       = module.repository.default_branch
}
