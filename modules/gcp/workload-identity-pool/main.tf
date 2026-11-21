module "context" {
  source = "../../_internal/context"

  context       = var.context
  name          = var.name
  module        = "gcp-workload-identity-pool"
  name_override = var.name_override
}

locals {
  providers = var.enabled ? var.oidc_providers : {}
}

# A workload identity pool has no labels, so module.context.labels has nowhere to go (MS-3.4
# applies to labelable resources).
resource "google_iam_workload_identity_pool" "this" {
  count = var.enabled ? 1 : 0

  project                   = var.project_id
  workload_identity_pool_id = module.context.name
  disabled                  = false

  # Provider-native protection (MS-5.4, ADR-0011). deletion_policy lives in state, so it still
  # refuses the delete after the module call is removed. A deleted pool's id stays reserved for
  # about 30 days, and every IAM binding on its principals stops matching. Providers carry no
  # protection: revoking trust must never be blocked.
  deletion_policy = var.deletion_protection.enabled ? "PREVENT" : "DELETE"

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z0-9-]{4,32}$", module.context.name)) && !startswith(module.context.name, "gcp-")
      error_message = "The pool id must be 4-32 characters of lowercase letters, digits and '-', and must not start with 'gcp-' (reserved by Google). Shorten name or component, or set context.name_prefix."
    }
  }
}

resource "google_iam_workload_identity_pool_provider" "this" {
  for_each = local.providers

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.this[0].workload_identity_pool_id
  workload_identity_pool_provider_id = each.key
  attribute_mapping                  = each.value.attribute_mapping
  attribute_condition                = each.value.attribute_condition
  disabled                           = each.value.disabled

  oidc {
    issuer_uri        = each.value.issuer_uri
    allowed_audiences = each.value.allowed_audiences
    jwks_json         = each.value.jwks_json
  }

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z0-9-]{4,32}$", each.key)) && !startswith(each.key, "gcp-")
      error_message = "Each oidc_providers key is the provider id: 4-32 characters of lowercase letters, digits and '-', not starting with 'gcp-' (reserved by Google)."
    }
  }
}
