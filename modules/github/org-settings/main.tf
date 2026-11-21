# GitHub resources are named verbatim and carry no labels (ADR-0016). The context call still
# validates context and name, so every module shares one input contract (MS-3.1). Every resource
# here configures the github provider's owner; none of them takes a name from this module.
module "context" {
  source = "../../_internal/context"

  context = var.context
  name    = var.name
  module  = "github-org-settings"
}

locals {
  actions = var.actions

  # Each nested block is sent only with the policy that uses it. The API rejects a repository list
  # unless enabled_repositories is "selected", and the provider skips the allowed-actions call
  # unless allowed_actions is "selected".
  allowed_actions_config      = local.actions.allowed_actions == "selected" ? [local.actions] : []
  enabled_repositories_config = local.actions.enabled_repositories == "selected" ? [local.actions] : []
}

# Destroying this resource does not restore anything: the provider writes a placeholder billing
# email to the organisation. prevent_destroy refuses that at plan; stop managing it with a
# `removed` block (lifecycle { destroy = false }) instead. The README shows how.
resource "github_organization_settings" "this" {
  count = var.enabled ? 1 : 0

  billing_email = var.billing_email

  name             = var.profile.display_name
  description      = var.profile.description
  email            = var.profile.email
  blog             = var.profile.blog
  company          = var.profile.company
  location         = var.profile.location
  twitter_username = var.profile.twitter_username

  default_repository_permission            = var.member_privileges.default_repository_permission
  members_can_create_repositories          = var.member_privileges.create_repositories
  members_can_create_public_repositories   = var.member_privileges.create_public_repositories
  members_can_create_private_repositories  = var.member_privileges.create_private_repositories
  members_can_create_internal_repositories = var.member_privileges.create_internal_repositories
  members_can_fork_private_repositories    = var.member_privileges.fork_private_repositories
  members_can_create_pages                 = var.member_privileges.create_pages
  members_can_create_public_pages          = var.member_privileges.create_public_pages
  members_can_create_private_pages         = var.member_privileges.create_private_pages

  has_organization_projects   = var.features.organization_projects
  has_repository_projects     = var.features.repository_projects
  web_commit_signoff_required = var.features.web_commit_signoff_required

  dependency_graph_enabled_for_new_repositories                = var.new_repository_security.dependency_graph
  dependabot_alerts_enabled_for_new_repositories               = var.new_repository_security.dependabot_alerts
  dependabot_security_updates_enabled_for_new_repositories     = var.new_repository_security.dependabot_security_updates
  secret_scanning_enabled_for_new_repositories                 = var.new_repository_security.secret_scanning
  secret_scanning_push_protection_enabled_for_new_repositories = var.new_repository_security.secret_scanning_push_protection
  advanced_security_enabled_for_new_repositories               = var.new_repository_security.advanced_security
  # Literal, not a knob (MS-5.4): the provider's destroy writes fixed values to the live
  # organisation instead of removing anything. Retire the module with `removed` blocks.
  lifecycle {
    prevent_destroy = true
  }
}

# Destroying this resource resets the organisation to all repositories and all actions, the
# loosest policy. prevent_destroy refuses that at plan; use a `removed` block instead.
resource "github_actions_organization_permissions" "this" {
  count = var.enabled ? 1 : 0

  enabled_repositories = local.actions.enabled_repositories
  allowed_actions      = local.actions.allowed_actions

  # Null leaves GitHub's setting alone (the attribute is computed). The provider never sends false.
  sha_pinning_required = local.actions.sha_pinning_required

  dynamic "allowed_actions_config" {
    for_each = local.allowed_actions_config
    content {
      github_owned_allowed = allowed_actions_config.value.github_owned_allowed
      verified_allowed     = allowed_actions_config.value.verified_allowed
      patterns_allowed     = allowed_actions_config.value.patterns_allowed
    }
  }

  dynamic "enabled_repositories_config" {
    for_each = local.enabled_repositories_config
    content {
      repository_ids = enabled_repositories_config.value.selected_repository_ids
    }
  }
  # Literal, not a knob (MS-5.4): the provider's destroy writes fixed values to the live
  # organisation instead of removing anything. Retire the module with `removed` blocks.
  lifecycle {
    prevent_destroy = true
  }
}

# Destroying this resource resets the token to read and pull request approval off: secure, but it
# overwrites whatever the root set, so it is refused at plan like the other two.
resource "github_actions_organization_workflow_permissions" "this" {
  count = var.enabled ? 1 : 0

  # The Actions permissions resource's id is the provider owner's login, so this resource always
  # targets the same organisation as the other two, with no second input that could disagree.
  organization_slug = github_actions_organization_permissions.this[0].id

  default_workflow_permissions     = var.workflow_permissions.default_workflow_permissions
  can_approve_pull_request_reviews = var.workflow_permissions.can_approve_pull_request_reviews
  # Literal, not a knob (MS-5.4): the provider's destroy writes fixed values to the live
  # organisation instead of removing anything. Retire the module with `removed` blocks.
  lifecycle {
    prevent_destroy = true
  }
}
