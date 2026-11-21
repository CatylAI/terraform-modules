module "context" {
  source = "../../_internal/context"

  context       = var.context
  name          = var.name
  module        = "gcp-service-account"
  name_override = var.name_override
}

# Service accounts carry no labels, so module.context.labels is not applied (see README). The
# module never creates a key or any other long-lived credential (MS-6.1); callers sign in through
# impersonation or Workload Identity Federation instead.

locals {
  project_roles = var.enabled ? var.project_roles : {}

  impersonation_members = var.enabled ? { for pair in flatten([
    for key, binding in var.impersonation : [
      for member in binding.members : { key = "${key}/${member}", role = binding.role, member = member }
    ]
  ]) : pair.key => { role = pair.role, member = pair.member } } : {}
}

resource "google_service_account" "this" {
  count = var.enabled ? 1 : 0

  project         = var.project_id
  account_id      = module.context.name
  display_name    = var.display_name
  description     = var.description
  deletion_policy = var.deletion_protection.enabled ? "PREVENT" : "DELETE"

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z][-a-z0-9]{4,28}[a-z0-9]$", module.context.name))
      error_message = "The service account id must be 6-30 characters of lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen. Shorten name or context.component, or set a shorter context.name_prefix. When adopting an existing account, set name_override to its id (ADR-0013)."
    }
  }
}

# Every binding is a single IAM member, so the module adds grants and never takes over (or
# removes) a binding it did not create.
resource "google_project_iam_member" "this" {
  for_each = local.project_roles

  project = var.project_id
  role    = each.value.role
  member  = google_service_account.this[0].member
}

resource "google_service_account_iam_member" "impersonation" {
  for_each = local.impersonation_members

  service_account_id = google_service_account.this[0].name
  role               = each.value.role
  member             = each.value.member
}
