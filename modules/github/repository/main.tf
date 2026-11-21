# The context call validates the shared inputs (MS-3.1). Its name and labels are not used: a
# GitHub repository is named verbatim, never prefixed, and GitHub has no labels (ADR-0016).
module "context" {
  source = "../../_internal/context"

  context = var.context
  name    = var.name
  module  = "github-repository"
}

locals {
  # var.name is the kebab-case instance id that context validates. repository_name covers live
  # repositories whose names are not kebab-case (.github, mixed case), so they adopt with no rename.
  repository_name = coalesce(var.repository_name, var.name)

  ruleset = var.default_branch_ruleset

  # Secret scanning and push protection need a paid feature on private and internal repositories.
  # With both off the block is omitted, so the module sends nothing GitHub could reject and
  # leaves the current setting alone (security_and_analysis is optional and computed).
  manage_security_and_analysis = var.security.secret_scanning || var.security.secret_scanning_push_protection || var.security.advanced_security != null

  labels            = var.enabled ? var.labels : {}
  actions_variables = var.enabled ? var.actions_variables : {}
}

resource "github_repository" "this" {
  count = var.enabled ? 1 : 0

  name         = local.repository_name
  visibility   = var.visibility
  description  = var.description
  homepage_url = var.homepage_url
  topics       = length(var.topics) > 0 ? var.topics : null

  has_issues      = var.features.issues
  has_projects    = var.features.projects
  has_wiki        = var.features.wiki
  has_discussions = var.features.discussions
  is_template     = var.features.template

  allow_merge_commit          = var.merge.allow_merge_commit
  allow_squash_merge          = var.merge.allow_squash_merge
  allow_rebase_merge          = var.merge.allow_rebase_merge
  allow_auto_merge            = var.merge.allow_auto_merge
  allow_update_branch         = var.merge.allow_update_branch
  delete_branch_on_merge      = var.merge.delete_branch_on_merge
  merge_commit_title          = var.merge.merge_commit_title
  merge_commit_message        = var.merge.merge_commit_message
  squash_merge_commit_title   = var.merge.squash_merge_commit_title
  squash_merge_commit_message = var.merge.squash_merge_commit_message

  # GitHub always allows forks of a public repository and the provider never sends the setting
  # for one, so a value here would diff on every plan.
  allow_forking               = var.visibility == "public" ? null : var.contributions.allow_forking
  web_commit_signoff_required = var.contributions.web_commit_signoff_required

  auto_init          = var.initial_commit.enabled
  archive_on_destroy = var.deletion_protection.enabled

  dynamic "security_and_analysis" {
    for_each = local.manage_security_and_analysis ? [var.security] : []
    content {
      dynamic "advanced_security" {
        for_each = security_and_analysis.value.advanced_security == null ? [] : [security_and_analysis.value.advanced_security]
        content {
          status = advanced_security.value ? "enabled" : "disabled"
        }
      }
      secret_scanning {
        status = security_and_analysis.value.secret_scanning ? "enabled" : "disabled"
      }
      secret_scanning_push_protection {
        status = security_and_analysis.value.secret_scanning_push_protection ? "enabled" : "disabled"
      }
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.repository_name) <= 100
      error_message = "A GitHub repository name must be at most 100 characters."
    }
  }
}

resource "github_repository_vulnerability_alerts" "this" {
  count = var.enabled ? 1 : 0

  repository = github_repository.this[0].name
  enabled    = var.security.vulnerability_alerts
}

resource "github_repository_ruleset" "this" {
  count = var.enabled && local.ruleset.enabled ? 1 : 0

  repository  = github_repository.this[0].name
  name        = local.ruleset.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  dynamic "bypass_actors" {
    for_each = local.ruleset.bypass_actors
    content {
      actor_type  = bypass_actors.value.actor_type
      actor_id    = bypass_actors.value.actor_id
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  rules {
    # Invariants of this ruleset: turn the ruleset off rather than these rules.
    deletion         = true
    non_fast_forward = true

    required_linear_history = local.ruleset.required_linear_history
    required_signatures     = local.ruleset.required_signatures

    pull_request {
      required_approving_review_count   = local.ruleset.required_approving_review_count
      require_code_owner_review         = local.ruleset.require_code_owner_review
      dismiss_stale_reviews_on_push     = local.ruleset.dismiss_stale_reviews_on_push
      require_last_push_approval        = local.ruleset.require_last_push_approval
      required_review_thread_resolution = local.ruleset.required_review_thread_resolution
    }

    dynamic "required_status_checks" {
      for_each = length(local.ruleset.required_status_checks) > 0 ? [local.ruleset] : []
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
}

resource "github_issue_label" "this" {
  for_each = local.labels

  repository  = github_repository.this[0].name
  name        = coalesce(each.value.name, each.key)
  color       = each.value.color
  description = each.value.description
}

resource "github_actions_variable" "this" {
  for_each = local.actions_variables

  repository    = github_repository.this[0].name
  variable_name = each.key
  value         = each.value
}

# Read back for the default_branch output: the resource's own default_branch attribute is
# deprecated in the github provider, and referencing it warns on every plan.
data "github_repository" "this" {
  count = var.enabled ? 1 : 0

  full_name = github_repository.this[0].full_name
}
