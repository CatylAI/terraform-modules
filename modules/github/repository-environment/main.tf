# GitHub resources are named verbatim and carry no labels (ADR-0016). The context call still
# validates context and name, so every module shares one input contract (MS-3.1).
module "context" {
  source = "../../_internal/context"

  context = var.context
  name    = var.name
  module  = "github-repository-environment"
}

locals {
  has_reviewers = length(var.reviewers.users) + length(var.reviewers.teams) > 0
  policy        = var.deployment_branch_policy

  # One deployment policy per pattern, keyed by kind and pattern, so adding a pattern never
  # re-keys the others.
  patterns = merge(
    { for b in local.policy.branches : "branch:${b}" => { branch_pattern = b, tag_pattern = null } },
    { for t in local.policy.tags : "tag:${t}" => { branch_pattern = null, tag_pattern = t } },
  )
  custom = length(local.patterns) > 0

  # The API takes protected_branches or custom_branch_policies, never both and never neither. Any
  # ref may deploy only when the block is omitted, which validation allows only with reviewers.
  branch_policy = local.policy.protected_branches || local.custom ? [{
    protected_branches     = local.policy.protected_branches
    custom_branch_policies = local.custom
  }] : []

  custom_patterns = var.enabled ? local.patterns : {}
  variables       = var.enabled ? var.variables : {}
}

resource "github_repository_environment" "this" {
  count = var.enabled ? 1 : 0

  repository        = var.repository
  environment       = var.environment_name
  can_admins_bypass = var.admin_bypass.enabled

  # Self-review is blocked whenever reviewers exist (no knob). Without reviewers GitHub has no
  # reviewer rule to carry the flag and reads it back false, so the module sends false too and an
  # imported environment plans clean.
  prevent_self_review = local.has_reviewers

  dynamic "reviewers" {
    for_each = local.has_reviewers ? [var.reviewers] : []
    content {
      users = reviewers.value.users
      teams = reviewers.value.teams
    }
  }

  dynamic "deployment_branch_policy" {
    for_each = local.branch_policy
    content {
      protected_branches     = deployment_branch_policy.value.protected_branches
      custom_branch_policies = deployment_branch_policy.value.custom_branch_policies
    }
  }
}

resource "github_repository_environment_deployment_policy" "this" {
  for_each = local.custom_patterns

  repository     = var.repository
  environment    = github_repository_environment.this[0].environment
  branch_pattern = each.value.branch_pattern
  tag_pattern    = each.value.tag_pattern
}

resource "github_actions_environment_variable" "this" {
  for_each = local.variables

  repository    = var.repository
  environment   = github_repository_environment.this[0].environment
  variable_name = each.key
  value         = each.value
}
