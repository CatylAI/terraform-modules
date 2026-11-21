output "ruleset_id" {
  description = "GitHub's numeric id of the ruleset."
  value       = module.ruleset.ruleset_id
}

output "node_id" {
  description = "GraphQL node id of the ruleset."
  value       = module.ruleset.node_id
}

output "name" {
  description = "The ruleset's name on GitHub."
  value       = module.ruleset.name
}
