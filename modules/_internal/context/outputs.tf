output "name" {
  description = "Resource name: name_override when set, otherwise <tenant>-<environment>-<component>-<name>."
  value       = local.name
}

output "name_prefix" {
  description = "context.name_prefix, or <tenant>-<environment>-<component>, for modules that derive several names."
  value       = local.name_prefix
}

output "labels" {
  description = "Caller labels merged with the reserved keys, folded to GCP label rules. Reserved keys win."
  value       = local.labels
}
