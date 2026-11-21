output "ruleset_id" {
  description = "GitHub's numeric id of the ruleset, the id an import uses. Null when the module is disabled."
  value       = one(github_organization_ruleset.this[*].ruleset_id)
}

output "node_id" {
  description = "GraphQL node id of the ruleset. Null when the module is disabled."
  value       = one(github_organization_ruleset.this[*].node_id)
}

output "name" {
  description = "The ruleset's name on GitHub. Null when the module is disabled."
  value       = one(github_organization_ruleset.this[*].name)
}
