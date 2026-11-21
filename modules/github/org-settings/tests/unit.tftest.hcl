# No credentials needed: every run plans (or applies) against a mock provider.
mock_provider "github" {
  mock_resource "github_organization_settings" {
    defaults = {
      id = "1234567"
    }
  }
  # The provider sets this resource's id to its owner's login.
  mock_resource "github_actions_organization_permissions" {
    defaults = {
      id = "acme"
    }
  }
}

variables {
  context = {
    tenant      = "acme"
    environment = "prod"
    component   = "github"
    repo        = "platform-github"
  }
  name          = "org-settings"
  billing_email = "billing@example.com"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = github_organization_settings.this[0].billing_email == "billing@example.com"
    error_message = "billing_email must be passed through."
  }
  assert {
    condition     = github_organization_settings.this[0].default_repository_permission == "read"
    error_message = "members must get read, not write, on every repository by default."
  }
  assert {
    condition     = github_organization_settings.this[0].members_can_create_public_repositories == false
    error_message = "members must not create public repositories by default."
  }
  assert {
    condition     = github_organization_settings.this[0].members_can_create_repositories == true && github_organization_settings.this[0].members_can_create_private_repositories == true
    error_message = "members must be able to create private repositories by default."
  }
  assert {
    condition     = github_organization_settings.this[0].members_can_create_internal_repositories == false
    error_message = "members must not create internal repositories by default."
  }
  assert {
    condition     = github_organization_settings.this[0].members_can_fork_private_repositories == false
    error_message = "members must not fork private repositories by default."
  }
  assert {
    condition = (
      github_organization_settings.this[0].members_can_create_pages == false &&
      github_organization_settings.this[0].members_can_create_public_pages == false &&
      github_organization_settings.this[0].members_can_create_private_pages == false
    )
    error_message = "members must not publish GitHub Pages sites by default."
  }
  assert {
    condition = (
      github_organization_settings.this[0].has_organization_projects == true &&
      github_organization_settings.this[0].has_repository_projects == true &&
      github_organization_settings.this[0].web_commit_signoff_required == false
    )
    error_message = "projects must default on and web commit sign-off off."
  }
  assert {
    condition = (
      github_organization_settings.this[0].dependency_graph_enabled_for_new_repositories == true &&
      github_organization_settings.this[0].dependabot_alerts_enabled_for_new_repositories == true &&
      github_organization_settings.this[0].dependabot_security_updates_enabled_for_new_repositories == true
    )
    error_message = "new repositories must get the dependency graph, Dependabot alerts and security updates by default."
  }
  assert {
    condition = (
      github_organization_settings.this[0].secret_scanning_enabled_for_new_repositories == true &&
      github_organization_settings.this[0].secret_scanning_push_protection_enabled_for_new_repositories == true
    )
    error_message = "new repositories must get secret scanning and push protection by default."
  }
  assert {
    condition     = github_organization_settings.this[0].advanced_security_enabled_for_new_repositories == false
    error_message = "paid Advanced Security must be off for new repositories by default."
  }
  assert {
    condition = (
      github_organization_settings.this[0].name == null &&
      github_organization_settings.this[0].description == null &&
      github_organization_settings.this[0].email == null &&
      github_organization_settings.this[0].blog == null &&
      github_organization_settings.this[0].company == null &&
      github_organization_settings.this[0].location == null &&
      github_organization_settings.this[0].twitter_username == null
    )
    error_message = "no profile field may be sent unless set."
  }
  assert {
    condition     = github_actions_organization_permissions.this[0].enabled_repositories == "all" && length(github_actions_organization_permissions.this[0].enabled_repositories_config) == 0
    error_message = "every repository must be allowed to run Actions by default, with no repository list."
  }
  assert {
    condition     = github_actions_organization_permissions.this[0].allowed_actions == "selected"
    error_message = "Actions must be limited to selected actions by default."
  }
  assert {
    condition = (
      length(github_actions_organization_permissions.this[0].allowed_actions_config) == 1 &&
      github_actions_organization_permissions.this[0].allowed_actions_config[0].github_owned_allowed == true &&
      github_actions_organization_permissions.this[0].allowed_actions_config[0].verified_allowed == true &&
      length(github_actions_organization_permissions.this[0].allowed_actions_config[0].patterns_allowed) == 0
    )
    error_message = "the selected actions must be GitHub-owned and verified-creator actions, with no extra patterns, by default."
  }
  assert {
    # The attribute is computed, so a null in config plans as unknown; the input default is what
    # decides that the module sends nothing.
    condition     = var.actions.sha_pinning_required == null
    error_message = "SHA pinning must not be managed by default (it fails every tag-pinned workflow and cannot be turned off through the provider)."
  }
  assert {
    condition     = github_actions_organization_workflow_permissions.this[0].default_workflow_permissions == "read"
    error_message = "the GITHUB_TOKEN must be read-only by default."
  }
  assert {
    condition     = github_actions_organization_workflow_permissions.this[0].can_approve_pull_request_reviews == false
    error_message = "workflows must not approve pull requests by default."
  }
}

# GitHub has no labels, and the organisation is the provider's owner: neither context nor name
# may reach any setting (ADR-0016).
run "name_and_context_are_not_sent" {
  command = plan
  variables {
    context = {
      tenant      = "initech"
      environment = "dev"
      component   = "org"
      repo        = "github-config"
      labels      = { team = "platform" }
      name_prefix = "should-not-apply"
    }
    name = "initech-org"
  }

  assert {
    condition     = github_organization_settings.this[0].name == null && github_organization_settings.this[0].description == null
    error_message = "name and context must not become the organisation's display name or description."
  }
}

run "disabled_creates_nothing" {
  command = plan
  variables {
    enabled = false
    actions = {
      enabled_repositories    = "selected"
      selected_repository_ids = [1296269]
      patterns_allowed        = ["acme/*"]
    }
  }

  assert {
    condition = (
      length(github_organization_settings.this) == 0 &&
      length(github_actions_organization_permissions.this) == 0 &&
      length(github_actions_organization_workflow_permissions.this) == 0
    )
    error_message = "enabled = false must create nothing."
  }
  assert {
    condition     = output.organization_id == null && output.organization == null
    error_message = "outputs must be null when disabled."
  }
}

run "outputs_after_apply" {
  command = apply

  assert {
    condition     = output.organization_id == "1234567" && output.organization == "acme"
    error_message = "organization_id and organization must be exported."
  }
  assert {
    condition     = github_actions_organization_workflow_permissions.this[0].organization_slug == "acme"
    error_message = "workflow permissions must target the provider's owner, read from the Actions permissions resource."
  }
}

# The shape a live organisation needs to adopt with no diff: every looser setting is an explicit
# override, and allowed_actions = "all" sends no allowed_actions_config.
run "adoption_overrides_pass_through" {
  command = plan
  variables {
    profile = {
      display_name = "Acme"
      email        = "contact@example.com"
      description  = ""
    }
    member_privileges = {
      create_public_repositories = true
      fork_private_repositories  = true
      create_pages               = true
      create_public_pages        = true
    }
    new_repository_security = {
      secret_scanning                 = false
      secret_scanning_push_protection = false
    }
    actions = {
      allowed_actions = "all"
    }
    workflow_permissions = {
      default_workflow_permissions     = "write"
      can_approve_pull_request_reviews = true
    }
  }

  assert {
    condition     = github_organization_settings.this[0].name == "Acme" && github_organization_settings.this[0].email == "contact@example.com" && github_organization_settings.this[0].description == ""
    error_message = "profile fields must be passed through."
  }
  assert {
    condition = (
      github_organization_settings.this[0].members_can_create_public_repositories == true &&
      github_organization_settings.this[0].members_can_fork_private_repositories == true &&
      github_organization_settings.this[0].members_can_create_pages == true &&
      github_organization_settings.this[0].members_can_create_public_pages == true &&
      github_organization_settings.this[0].members_can_create_private_pages == false
    )
    error_message = "member privilege overrides must apply, and the rest keep their defaults."
  }
  assert {
    condition     = github_organization_settings.this[0].default_repository_permission == "read" && github_organization_settings.this[0].members_can_create_internal_repositories == false
    error_message = "member privilege overrides must keep the other defaults."
  }
  assert {
    condition = (
      github_organization_settings.this[0].secret_scanning_enabled_for_new_repositories == false &&
      github_organization_settings.this[0].secret_scanning_push_protection_enabled_for_new_repositories == false &&
      github_organization_settings.this[0].dependabot_alerts_enabled_for_new_repositories == true
    )
    error_message = "new-repository security overrides must apply and keep the other defaults."
  }
  assert {
    condition     = github_actions_organization_permissions.this[0].allowed_actions == "all" && length(github_actions_organization_permissions.this[0].allowed_actions_config) == 0
    error_message = "allowed_actions = all must send no allowed_actions_config."
  }
  assert {
    condition     = github_actions_organization_workflow_permissions.this[0].default_workflow_permissions == "write" && github_actions_organization_workflow_permissions.this[0].can_approve_pull_request_reviews == true
    error_message = "workflow permission overrides must apply."
  }
}

run "selected_repositories_and_patterns" {
  command = plan
  variables {
    actions = {
      enabled_repositories    = "selected"
      selected_repository_ids = [1296269, 1300192]
      verified_allowed        = false
      patterns_allowed        = ["acme/*", "hashicorp/setup-terraform@v3"]
      sha_pinning_required    = true
    }
  }

  assert {
    condition     = github_actions_organization_permissions.this[0].enabled_repositories == "selected" && github_actions_organization_permissions.this[0].enabled_repositories_config[0].repository_ids == toset([1296269, 1300192])
    error_message = "selected repositories must be sent as enabled_repositories_config."
  }
  assert {
    condition = (
      github_actions_organization_permissions.this[0].allowed_actions_config[0].github_owned_allowed == true &&
      github_actions_organization_permissions.this[0].allowed_actions_config[0].verified_allowed == false &&
      github_actions_organization_permissions.this[0].allowed_actions_config[0].patterns_allowed == toset(["acme/*", "hashicorp/setup-terraform@v3"])
    )
    error_message = "allowed-action overrides and patterns must be passed through."
  }
  assert {
    condition     = github_actions_organization_permissions.this[0].sha_pinning_required == true
    error_message = "sha_pinning_required must be sent when set."
  }
}

run "local_only_actions" {
  command = plan
  variables {
    actions = { allowed_actions = "local_only" }
  }

  assert {
    condition     = github_actions_organization_permissions.this[0].allowed_actions == "local_only" && length(github_actions_organization_permissions.this[0].allowed_actions_config) == 0
    error_message = "allowed_actions = local_only must send no allowed_actions_config."
  }
}

run "profile_and_enterprise_settings" {
  command = plan
  variables {
    profile = {
      display_name     = "Acme Corporation"
      description      = "Tools and services for road runners"
      email            = "hello@example.com"
      blog             = "https://www.example.com"
      company          = "Acme"
      location         = "Arizona"
      twitter_username = "acme_corp"
    }
    member_privileges = {
      default_repository_permission = "none"
      create_internal_repositories  = true
      create_private_pages          = true
      create_pages                  = true
    }
    features = {
      repository_projects         = false
      web_commit_signoff_required = true
    }
    new_repository_security = { advanced_security = true }
  }

  assert {
    condition = (
      github_organization_settings.this[0].name == "Acme Corporation" &&
      github_organization_settings.this[0].blog == "https://www.example.com" &&
      github_organization_settings.this[0].company == "Acme" &&
      github_organization_settings.this[0].location == "Arizona" &&
      github_organization_settings.this[0].twitter_username == "acme_corp"
    )
    error_message = "every profile field must be passed through."
  }
  assert {
    condition = (
      github_organization_settings.this[0].default_repository_permission == "none" &&
      github_organization_settings.this[0].members_can_create_internal_repositories == true &&
      github_organization_settings.this[0].members_can_create_private_pages == true &&
      github_organization_settings.this[0].members_can_create_public_pages == false
    )
    error_message = "member privilege overrides must apply and keep public pages off."
  }
  assert {
    condition     = github_organization_settings.this[0].has_repository_projects == false && github_organization_settings.this[0].has_organization_projects == true && github_organization_settings.this[0].web_commit_signoff_required == true
    error_message = "feature overrides must apply and keep the other defaults."
  }
  assert {
    condition     = github_organization_settings.this[0].advanced_security_enabled_for_new_repositories == true && github_organization_settings.this[0].secret_scanning_enabled_for_new_repositories == true
    error_message = "advanced_security must be sent when set, keeping secret scanning on."
  }
  assert {
    condition     = github_actions_organization_permissions.this[0].allowed_actions == "selected" && github_actions_organization_workflow_permissions.this[0].default_workflow_permissions == "read"
    error_message = "unrelated Actions defaults must survive other overrides."
  }
}

# --- validations: every one fails on bad input (MS-2.7) ------------------------------------------

run "rejects_missing_billing_email" {
  command = plan
  variables { billing_email = null }
  expect_failures = [var.billing_email]
}

run "rejects_malformed_billing_email" {
  command = plan
  variables { billing_email = "billing.example.com" }
  expect_failures = [var.billing_email]
}

run "rejects_malformed_profile_email" {
  command = plan
  variables { profile = { email = "contact at example.com" } }
  expect_failures = [var.profile]
}

run "rejects_long_description" {
  command = plan
  variables { profile = { description = "An organisation description that keeps going well past the limit GitHub sets on it, which is one hundred and sixty characters in total, so this one must be rejected by validation" } }
  expect_failures = [var.profile]
}

run "rejects_invalid_twitter_username" {
  command = plan
  variables { profile = { twitter_username = "@acme" } }
  expect_failures = [var.profile]
}

run "rejects_unknown_repository_permission" {
  command = plan
  variables { member_privileges = { default_repository_permission = "maintain" } }
  expect_failures = [var.member_privileges]
}

run "rejects_push_protection_without_scanning" {
  command = plan
  variables { new_repository_security = { secret_scanning = false } }
  expect_failures = [var.new_repository_security]
}

run "rejects_dependabot_alerts_without_graph" {
  command = plan
  variables { new_repository_security = { dependency_graph = false } }
  expect_failures = [var.new_repository_security]
}

run "rejects_security_updates_without_alerts" {
  command = plan
  variables { new_repository_security = { dependabot_alerts = false } }
  expect_failures = [var.new_repository_security]
}

run "rejects_unknown_enabled_repositories" {
  command = plan
  variables { actions = { enabled_repositories = "some" } }
  expect_failures = [var.actions]
}

run "rejects_unknown_allowed_actions" {
  command = plan
  variables { actions = { allowed_actions = "verified" } }
  expect_failures = [var.actions]
}

run "rejects_selected_repositories_without_ids" {
  command = plan
  variables { actions = { enabled_repositories = "selected" } }
  expect_failures = [var.actions]
}

run "rejects_repository_ids_without_selected" {
  command = plan
  variables { actions = { selected_repository_ids = [1296269] } }
  expect_failures = [var.actions]
}

run "rejects_non_positive_repository_id" {
  command = plan
  variables {
    actions = {
      enabled_repositories    = "selected"
      selected_repository_ids = [0]
    }
  }
  expect_failures = [var.actions]
}

run "rejects_patterns_without_selected_actions" {
  command = plan
  variables {
    actions = {
      allowed_actions  = "all"
      patterns_allowed = ["acme/*"]
    }
  }
  expect_failures = [var.actions]
}

run "rejects_blank_pattern" {
  command = plan
  variables { actions = { patterns_allowed = ["acme/deploy action@v1"] } }
  expect_failures = [var.actions]
}

run "rejects_unknown_workflow_permission" {
  command = plan
  variables { workflow_permissions = { default_workflow_permissions = "admin" } }
  expect_failures = [var.workflow_permissions]
}
