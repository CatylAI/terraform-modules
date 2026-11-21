output "full_name" {
  description = "Repository full name, <owner>/<name>. Null when the module is disabled."
  value       = one(github_repository.this[*].full_name)
}

output "node_id" {
  description = "GraphQL node id of the repository. Null when the module is disabled."
  value       = one(github_repository.this[*].node_id)
}

output "default_branch" {
  description = "Name of the repository's default branch, as GitHub reports it. Null when the module is disabled."
  value       = one(data.github_repository.this[*].default_branch)
}
