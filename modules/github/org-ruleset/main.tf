# The context call validates the shared inputs (MS-3.1). Its name and labels are not used: a
# GitHub ruleset is named verbatim, never prefixed, and GitHub has no labels (ADR-0016).
module "context" {
  source = "../../_internal/context"

  context = var.context
  name    = var.name
  module  = "github-org-ruleset"
}

locals {
  # var.name is the kebab-case instance id that context validates. ruleset_name covers names that
  # are not kebab-case ("Release branches: protect"), so a live ruleset adopts with no rename.
  ruleset_name = coalesce(var.ruleset_name, var.name)

  rules        = var.rules
  pull_request = local.rules.pull_request != null && try(local.rules.pull_request.enabled, false) ? [local.rules.pull_request] : []
}

resource "github_organization_ruleset" "this" {
  count = var.enabled ? 1 : 0

  name        = local.ruleset_name
  target      = var.target
  enforcement = var.enforcement

  conditions {
    ref_name {
      include = var.conditions.ref_name.include
      exclude = var.conditions.ref_name.exclude
    }
    repository_name {
      include = var.conditions.repository_name.include
      exclude = var.conditions.repository_name.exclude
    }
  }

  dynamic "bypass_actors" {
    for_each = var.bypass_actors
    content {
      actor_type  = bypass_actors.value.actor_type
      actor_id    = bypass_actors.value.actor_id
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  rules {
    deletion                = local.rules.deletion
    non_fast_forward        = local.rules.non_fast_forward
    creation                = local.rules.creation
    update                  = local.rules.update
    required_linear_history = local.rules.required_linear_history
    required_signatures     = local.rules.required_signatures

    dynamic "pull_request" {
      for_each = local.pull_request
      content {
        required_approving_review_count   = pull_request.value.required_approving_review_count
        require_code_owner_review         = pull_request.value.require_code_owner_review
        dismiss_stale_reviews_on_push     = pull_request.value.dismiss_stale_reviews_on_push
        require_last_push_approval        = pull_request.value.require_last_push_approval
        required_review_thread_resolution = pull_request.value.required_review_thread_resolution
      }
    }

    dynamic "required_status_checks" {
      for_each = length(local.rules.required_status_checks) > 0 ? [local.rules] : []
      content {
        strict_required_status_checks_policy = required_status_checks.value.strict_required_status_checks

        dynamic "required_check" {
          for_each = required_status_checks.value.required_status_checks
          content {
            context        = required_check.key
            integration_id = required_check.value.integration_id
          }
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.ruleset_name) <= 100
      error_message = "A GitHub ruleset name must be at most 100 characters."
    }
  }
}
