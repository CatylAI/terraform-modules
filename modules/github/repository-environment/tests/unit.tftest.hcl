mock_provider "github" {}

variables {
  context = {
    tenant      = "acme"
    environment = "prod"
    component   = "delivery"
    repo        = "delivery-stack"
  }
  name             = "orders-production"
  repository       = "orders-service"
  environment_name = "production"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = github_repository_environment.this[0].environment == "production" && github_repository_environment.this[0].repository == "orders-service"
    error_message = "the environment must be created on the given repository, under environment_name verbatim (ADR-0016)."
  }
  assert {
    condition     = github_repository_environment.this[0].can_admins_bypass == false
    error_message = "admin bypass must be off by default."
  }
  assert {
    condition     = length(github_repository_environment.this[0].deployment_branch_policy) == 1
    error_message = "a deployment branch policy must be set by default, so the environment is never open."
  }
  assert {
    condition     = github_repository_environment.this[0].deployment_branch_policy[0].protected_branches == true && github_repository_environment.this[0].deployment_branch_policy[0].custom_branch_policies == false
    error_message = "deployments must come only from protected branches by default, with no custom branch policies."
  }
  assert {
    condition     = length(github_repository_environment.this[0].reviewers) == 0 && github_repository_environment.this[0].prevent_self_review == false
    error_message = "no reviewers by default; prevent_self_review follows reviewers, so an imported environment without reviewers plans clean."
  }
  assert {
    condition     = github_repository_environment.this[0].wait_timer == null
    error_message = "no wait timer is set."
  }
  assert {
    condition     = length(github_repository_environment_deployment_policy.this) == 0 && length(github_actions_environment_variable.this) == 0
    error_message = "no custom branch policies and no variables by default."
  }
  assert {
    condition     = output.environment_name == "production"
    error_message = "environment_name output must be the environment's name."
  }
}

run "disabled_creates_nothing" {
  command = plan
  variables {
    enabled                  = false
    reviewers                = { users = [1001] }
    deployment_branch_policy = { protected_branches = false, custom_patterns = { main = { branch_pattern = "main" } } }
    variables                = { DEPLOY_REGION = "us-east1" }
  }

  assert {
    condition     = length(github_repository_environment.this) == 0 && length(github_repository_environment_deployment_policy.this) == 0 && length(github_actions_environment_variable.this) == 0
    error_message = "enabled = false must create nothing."
  }
  assert {
    condition     = output.environment_name == null
    error_message = "environment_name must be null when disabled."
  }
}

run "environment_name_used_verbatim" {
  command = plan
  variables { environment_name = "Production EU" }

  assert {
    condition     = github_repository_environment.this[0].environment == "Production EU" && output.environment_name == "Production EU"
    error_message = "environment_name must be used verbatim, with no context prefix (ADR-0016)."
  }
}

run "no_reviewers_with_protected_branch_policy_passes" {
  command = plan
  variables { deployment_branch_policy = { protected_branches = true } }

  assert {
    condition     = github_repository_environment.this[0].deployment_branch_policy[0].protected_branches == true && length(github_repository_environment.this[0].reviewers) == 0
    error_message = "an environment with no reviewers and a protected-branch-only policy must plan."
  }
}

run "rejects_no_reviewers_with_open_policy" {
  command = plan
  variables { deployment_branch_policy = { protected_branches = false } }
  expect_failures = [var.deployment_branch_policy]
}

run "rejects_no_reviewers_with_custom_patterns" {
  command = plan
  variables {
    deployment_branch_policy = { protected_branches = false, custom_patterns = { main = { branch_pattern = "main" } } }
  }
  expect_failures = [var.deployment_branch_policy]
}

run "reviewers_block_self_review" {
  command = plan
  variables { reviewers = { users = [1001], teams = [2002] } }

  assert {
    condition     = github_repository_environment.this[0].prevent_self_review == true
    error_message = "self-review must be blocked whenever reviewers are set."
  }
  assert {
    condition     = contains(github_repository_environment.this[0].reviewers[0].users, 1001) && contains(github_repository_environment.this[0].reviewers[0].teams, 2002)
    error_message = "user and team reviewers must be passed through by id."
  }
  assert {
    condition     = github_repository_environment.this[0].can_admins_bypass == false && github_repository_environment.this[0].deployment_branch_policy[0].protected_branches == true
    error_message = "reviewers must not loosen the other defaults."
  }
}

run "accepts_six_reviewers" {
  command = plan
  variables { reviewers = { users = [1, 2, 3], teams = [4, 5, 6] } }

  assert {
    condition     = length(github_repository_environment.this[0].reviewers[0].users) + length(github_repository_environment.this[0].reviewers[0].teams) == 6
    error_message = "six reviewers in total is the documented maximum and must be accepted."
  }
}

run "rejects_more_than_six_reviewers" {
  command = plan
  variables { reviewers = { users = [1, 2, 3, 4], teams = [5, 6, 7] } }
  expect_failures = [var.reviewers]
}

run "rejects_non_positive_reviewer_id" {
  command = plan
  variables { reviewers = { users = [0] } }
  expect_failures = [var.reviewers]
}

run "rejects_fractional_reviewer_id" {
  command = plan
  variables { reviewers = { teams = [1.5] } }
  expect_failures = [var.reviewers]
}

run "reviewers_with_custom_patterns" {
  command = plan
  variables {
    reviewers = { teams = [2002] }
    deployment_branch_policy = {
      protected_branches = false
      custom_patterns = {
        main     = { branch_pattern = "main" }
        releases = { tag_pattern = "v*" }
      }
    }
  }

  assert {
    condition     = github_repository_environment.this[0].deployment_branch_policy[0].protected_branches == false && github_repository_environment.this[0].deployment_branch_policy[0].custom_branch_policies == true
    error_message = "custom patterns must switch the policy to custom branch policies."
  }
  assert {
    condition     = length(github_repository_environment_deployment_policy.this) == 2
    error_message = "one deployment policy per custom pattern."
  }
  assert {
    condition     = github_repository_environment_deployment_policy.this["main"].branch_pattern == "main" && github_repository_environment_deployment_policy.this["main"].tag_pattern == null && github_repository_environment_deployment_policy.this["releases"].tag_pattern == "v*"
    error_message = "branch and tag patterns must be passed through on their own keys."
  }
  assert {
    condition     = github_repository_environment_deployment_policy.this["main"].environment == "production" && github_repository_environment_deployment_policy.this["main"].repository == "orders-service"
    error_message = "deployment policies must attach to this environment."
  }
}

run "reviewers_with_open_policy" {
  command = plan
  variables {
    reviewers                = { users = [1001] }
    deployment_branch_policy = { protected_branches = false }
  }

  assert {
    condition     = length(github_repository_environment.this[0].deployment_branch_policy) == 0 && github_repository_environment.this[0].prevent_self_review == true
    error_message = "with reviewers, an open branch policy omits the block (the API's 'any branch'), and approval still gates every deployment."
  }
}

run "rejects_protected_branches_with_custom_patterns" {
  command = plan
  variables {
    reviewers                = { users = [1001] }
    deployment_branch_policy = { custom_patterns = { main = { branch_pattern = "main" } } }
  }
  expect_failures = [var.deployment_branch_policy]
}

run "rejects_pattern_with_both_branch_and_tag" {
  command = plan
  variables {
    reviewers                = { users = [1001] }
    deployment_branch_policy = { protected_branches = false, custom_patterns = { both = { branch_pattern = "main", tag_pattern = "v*" } } }
  }
  expect_failures = [var.deployment_branch_policy]
}

run "rejects_pattern_with_neither_branch_nor_tag" {
  command = plan
  variables {
    reviewers                = { users = [1001] }
    deployment_branch_policy = { protected_branches = false, custom_patterns = { empty = {} } }
  }
  expect_failures = [var.deployment_branch_policy]
}

run "admin_bypass_override_keeps_other_defaults" {
  command = plan
  variables { admin_bypass = { enabled = true } }

  assert {
    condition     = github_repository_environment.this[0].can_admins_bypass == true
    error_message = "admin_bypass.enabled must turn admin bypass on."
  }
  assert {
    condition     = github_repository_environment.this[0].deployment_branch_policy[0].protected_branches == true
    error_message = "the protected-branch policy must survive the admin bypass override."
  }
}

run "variables_come_from_map" {
  command = plan
  variables {
    variables = {
      DEPLOY_REGION = "us-east1"
      AGENT_ENABLED = "true"
    }
  }

  assert {
    condition     = length(github_actions_environment_variable.this) == 2
    error_message = "one environment variable per map entry."
  }
  assert {
    condition     = github_actions_environment_variable.this["DEPLOY_REGION"].variable_name == "DEPLOY_REGION" && github_actions_environment_variable.this["DEPLOY_REGION"].value == "us-east1" && github_actions_environment_variable.this["AGENT_ENABLED"].value == "true"
    error_message = "variable names and values must come from the map."
  }
  assert {
    condition     = github_actions_environment_variable.this["DEPLOY_REGION"].environment == "production" && github_actions_environment_variable.this["DEPLOY_REGION"].repository == "orders-service"
    error_message = "variables must attach to this environment."
  }
}

run "rejects_secret_like_variable_name" {
  command = plan
  variables { variables = { API_TOKEN = "not-a-real-token" } }
  expect_failures = [var.variables]
}

run "rejects_lowercase_variable_name" {
  command = plan
  variables { variables = { deploy_region = "us-east1" } }
  expect_failures = [var.variables]
}

run "rejects_github_prefixed_variable_name" {
  command = plan
  variables { variables = { GITHUB_REGION = "us-east1" } }
  expect_failures = [var.variables]
}

run "rejects_variable_name_starting_with_digit" {
  command = plan
  variables { variables = { "1REGION" = "us-east1" } }
  expect_failures = [var.variables]
}

run "rejects_more_than_100_variables" {
  command = plan
  variables { variables = { for i in range(101) : "VAR_${i}" => "x" } }
  expect_failures = [var.variables]
}

run "rejects_invalid_repository" {
  command = plan
  variables { repository = "acme/orders-service" }
  expect_failures = [var.repository]
}

run "rejects_empty_environment_name" {
  command = plan
  variables { environment_name = "" }
  expect_failures = [var.environment_name]
}

run "rejects_padded_environment_name" {
  command = plan
  variables { environment_name = " production" }
  expect_failures = [var.environment_name]
}

run "rejects_environment_name_over_255_characters" {
  command = plan
  variables { environment_name = join("", [for i in range(256) : "a"]) }
  expect_failures = [var.environment_name]
}
