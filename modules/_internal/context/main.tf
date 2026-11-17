locals {
  name_prefix = coalesce(var.context.name_prefix, join("-", [var.context.tenant, var.context.environment, var.context.component]))
  name        = coalesce(var.name_override, "${local.name_prefix}-${var.name}")

  # Reserved keys are applied last so a caller cannot override them (MS-3.4). Values come from
  # validated inputs, but repo names may carry uppercase and dots, so every value is folded to
  # GCP label rules: lowercase, [a-z0-9_-], at most 63 characters.
  reserved_labels = {
    "managed-by" = "terraform"
    tenant       = var.context.tenant
    environment  = var.context.environment
    component    = var.context.component
    repo         = var.context.repo
    module       = var.module
  }
  sanitized_reserved = { for k, v in local.reserved_labels : k => substr(replace(lower(v), "/[^a-z0-9_-]/", "-"), 0, 63) }

  labels = merge(var.context.labels, local.sanitized_reserved)
}
