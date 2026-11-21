# No credentials needed: every run plans (or applies) against a mock provider.
mock_provider "github" {}

variables {
  context = {
    tenant      = "acme"
    environment = "prod"
    component   = "github"
    repo        = "platform-github"
  }
  name            = "release-app"
  installation_id = 12345678
  repositories    = ["orders-service", "billing-api"]
}

run "secure_defaults" {
  command = plan

  assert {
    condition = alltrue([
      for k, r in github_app_installation_repository.this : r.installation_id == "12345678" && r.repository == k
    ])
    error_message = "every attachment must carry the installation id as given and the repository named by its key."
  }
  assert {
    condition     = keys(github_app_installation_repository.this) == ["billing-api", "orders-service"]
    error_message = "attachments must be keyed by repository name, never by list index (MS-2.6)."
  }
}

run "one_attachment_per_repository" {
  command = plan
  variables {
    repositories = ["orders-service", "billing-api", "storefront"]
  }

  assert {
    condition     = length(github_app_installation_repository.this) == 3
    error_message = "the module must create exactly one attachment per listed repository."
  }
  assert {
    condition     = toset([for r in github_app_installation_repository.this : r.repository]) == toset(["orders-service", "billing-api", "storefront"])
    error_message = "the attached repositories must be exactly the listed ones."
  }
}

run "repository_names_are_verbatim_and_unlabelled" {
  command = plan
  variables {
    context = {
      tenant      = "initech"
      environment = "dev"
      component   = "apps"
      repo        = "github-config"
      labels      = { team = "platform" }
      name_prefix = "should-not-apply"
    }
    # GitHub names need not be kebab-case; neither the prefix nor name may change them (ADR-0016).
    repositories = [".github", "Legacy_Service.v2"]
  }

  assert {
    condition     = toset([for r in github_app_installation_repository.this : r.repository]) == toset([".github", "Legacy_Service.v2"])
    error_message = "repository names must be used verbatim; context, name_prefix and name must not change them (ADR-0016)."
  }
}

run "disabled_creates_nothing" {
  command = plan
  variables {
    enabled = false
  }

  assert {
    condition     = length(github_app_installation_repository.this) == 0
    error_message = "enabled = false must create nothing."
  }
  assert {
    condition     = output.repositories == null
    error_message = "outputs must be null when disabled."
  }
}

run "disabled_accepts_null_installation_id" {
  command = plan
  variables {
    # A root drives both from one optional variable: no installation id, no attachments.
    enabled         = false
    installation_id = null
    repositories    = []
  }

  assert {
    condition     = length(github_app_installation_repository.this) == 0 && output.repositories == null
    error_message = "enabled = false with a null installation_id and no repositories must plan and create nothing."
  }
}

run "outputs_after_apply" {
  command = apply

  assert {
    condition     = output.repositories == toset(["orders-service", "billing-api"])
    error_message = "repositories must export the attached repository names."
  }
}

run "rejects_zero_installation_id" {
  command = plan
  variables {
    installation_id = 0
  }
  expect_failures = [var.installation_id]
}

run "rejects_negative_installation_id" {
  command = plan
  variables {
    installation_id = -42
  }
  expect_failures = [var.installation_id]
}

run "rejects_fractional_installation_id" {
  command = plan
  variables {
    installation_id = 1234.5
  }
  expect_failures = [var.installation_id]
}

run "rejects_null_installation_id_while_enabled" {
  command = plan
  variables {
    installation_id = null
  }
  expect_failures = [var.installation_id]
}

run "rejects_empty_repositories" {
  command = plan
  variables {
    repositories = []
  }
  expect_failures = [var.repositories]
}

run "rejects_owner_qualified_repository" {
  command = plan
  variables {
    repositories = ["acme/orders-service"]
  }
  expect_failures = [var.repositories]
}

run "rejects_repository_with_space" {
  command = plan
  variables {
    repositories = ["orders service"]
  }
  expect_failures = [var.repositories]
}

run "rejects_dot_repository" {
  command = plan
  variables {
    repositories = [".."]
  }
  expect_failures = [var.repositories]
}

run "rejects_repository_name_too_long" {
  command = plan
  variables {
    repositories = ["a${join("", [for i in range(100) : "b"])}"]
  }
  expect_failures = [var.repositories]
}

run "rejects_case_insensitive_duplicates" {
  command = plan
  variables {
    repositories = ["Orders-Service", "orders-service"]
  }
  expect_failures = [var.repositories]
}
