# No credentials needed: every run plans (or applies) against a mock provider.
mock_provider "github" {
  mock_resource "github_repository" {
    defaults = {
      full_name = "acme/orders-service"
      node_id   = "R_kgDOAAAAAA"
    }
  }
  mock_data "github_repository" {
    defaults = {
      default_branch = "main"
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
  name       = "orders-service"
  visibility = "private"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = github_repository.this[0].name == "orders-service" && github_repository.this[0].visibility == "private"
    error_message = "the repository must be named var.name verbatim, with the given visibility."
  }
  assert {
    condition     = github_repository.this[0].archive_on_destroy == true
    error_message = "destroy must archive the repository and keep its history by default."
  }
  assert {
    condition     = github_repository.this[0].security_and_analysis[0].secret_scanning[0].status == "enabled"
    error_message = "secret scanning must be on by default."
  }
  assert {
    condition     = github_repository.this[0].security_and_analysis[0].secret_scanning_push_protection[0].status == "enabled"
    error_message = "push protection must be on by default."
  }
  assert {
    condition     = length(github_repository.this[0].security_and_analysis[0].advanced_security) == 0
    error_message = "advanced_security must not be sent by default; split licensing rejects it."
  }
  assert {
    condition     = github_repository_vulnerability_alerts.this[0].enabled == true && github_repository_vulnerability_alerts.this[0].repository == "orders-service"
    error_message = "vulnerability alerts must be on by default."
  }
  assert {
    condition     = github_repository.this[0].has_issues == true && github_repository.this[0].has_wiki == false && github_repository.this[0].has_projects == false && github_repository.this[0].has_discussions == false && github_repository.this[0].is_template == false
    error_message = "features must default to issues on; wiki, projects, discussions and template off."
  }
  assert {
    condition     = github_repository.this[0].allow_forking == false && github_repository.this[0].web_commit_signoff_required == false
    error_message = "private forking must be off by default."
  }
  assert {
    condition     = github_repository.this[0].delete_branch_on_merge == true && github_repository.this[0].allow_auto_merge == false && github_repository.this[0].auto_init == true
    error_message = "head branches must be deleted on merge, auto-merge off, and a new repository initialised."
  }
  assert {
    condition     = length(github_repository_ruleset.this) == 1
    error_message = "the default-branch ruleset must exist by default."
  }
  assert {
    condition = (
      github_repository_ruleset.this[0].repository == "orders-service" &&
      github_repository_ruleset.this[0].name == "default-branch" &&
      github_repository_ruleset.this[0].target == "branch" &&
      github_repository_ruleset.this[0].enforcement == "active" &&
      github_repository_ruleset.this[0].conditions[0].ref_name[0].include == tolist(["~DEFAULT_BRANCH"]) &&
      length(github_repository_ruleset.this[0].conditions[0].ref_name[0].exclude) == 0
    )
    error_message = "the ruleset must be active on the default branch."
  }
  assert {
    condition     = github_repository_ruleset.this[0].rules[0].non_fast_forward == true && github_repository_ruleset.this[0].rules[0].deletion == true
    error_message = "the ruleset must block force pushes and branch deletion."
  }
  assert {
    condition = (
      length(github_repository_ruleset.this[0].rules[0].pull_request) == 1 &&
      github_repository_ruleset.this[0].rules[0].pull_request[0].require_code_owner_review == true &&
      github_repository_ruleset.this[0].rules[0].pull_request[0].required_approving_review_count == 1 &&
      github_repository_ruleset.this[0].rules[0].pull_request[0].dismiss_stale_reviews_on_push == true
    )
    error_message = "the ruleset must require a pull request with one approval and code-owner review, dismissing stale approvals."
  }
  assert {
    condition     = length(github_repository_ruleset.this[0].rules[0].required_status_checks) == 0
    error_message = "no status check is required by default (a required check stalls GITHUB_TOKEN pull requests)."
  }
  assert {
    condition     = length(github_repository_ruleset.this[0].bypass_actors) == 0
    error_message = "nobody may bypass the ruleset by default."
  }
  assert {
    condition     = length(github_issue_label.this) == 0 && length(github_actions_variable.this) == 0
    error_message = "no labels or Actions variables by default."
  }
}

run "name_is_verbatim_and_unlabelled" {
  command = plan
  variables {
    context = {
      tenant      = "initech"
      environment = "dev"
      component   = "repos"
      repo        = "github-config"
      labels      = { team = "platform" }
      name_prefix = "should-not-apply"
    }
    name   = "billing-api"
    topics = ["payments"]
  }

  assert {
    condition     = github_repository.this[0].name == "billing-api"
    error_message = "the repository name must be var.name verbatim; context and name_prefix must not change it (ADR-0016)."
  }
  assert {
    condition     = github_repository.this[0].topics == toset(["payments"])
    error_message = "topics must be exactly the input; context labels must not be added to them (ADR-0016)."
  }
}

run "disabled_creates_nothing" {
  command = plan
  variables {
    enabled           = false
    labels            = { bug = { color = "d73a4a" } }
    actions_variables = { AGENT_ENABLED = "false" }
    default_branch_ruleset = {
      required_status_checks = { gate = {} }
    }
  }

  assert {
    condition = (
      length(github_repository.this) == 0 &&
      length(github_repository_ruleset.this) == 0 &&
      length(github_repository_vulnerability_alerts.this) == 0 &&
      length(github_issue_label.this) == 0 &&
      length(github_actions_variable.this) == 0 &&
      length(data.github_repository.this) == 0
    )
    error_message = "enabled = false must create nothing."
  }
  assert {
    condition     = output.full_name == null && output.node_id == null && output.default_branch == null
    error_message = "outputs must be null when disabled."
  }
}

run "outputs_after_apply" {
  command = apply

  assert {
    condition     = output.full_name == "acme/orders-service" && output.node_id == "R_kgDOAAAAAA" && output.default_branch == "main"
    error_message = "full_name, node_id and default_branch must be exported."
  }
}

run "ruleset_can_be_turned_off" {
  command = plan
  variables {
    default_branch_ruleset = { enabled = false }
  }

  assert {
    condition     = length(github_repository_ruleset.this) == 0
    error_message = "default_branch_ruleset.enabled = false must remove the ruleset."
  }
  assert {
    condition     = length(github_repository.this) == 1 && github_repository.this[0].security_and_analysis[0].secret_scanning[0].status == "enabled" && github_repository_vulnerability_alerts.this[0].enabled == true
    error_message = "turning the ruleset off must leave the repository and its security features alone."
  }
}

run "required_checks_appear_when_listed" {
  command = plan
  variables {
    default_branch_ruleset = {
      required_status_checks = {
        gate  = {}
        build = { integration_id = 15368 }
      }
      strict_required_status_checks = true
    }
  }

  assert {
    condition     = length(github_repository_ruleset.this[0].rules[0].required_status_checks) == 1 && length(github_repository_ruleset.this[0].rules[0].required_status_checks[0].required_check) == 2
    error_message = "one required_check per listed check."
  }
  assert {
    condition = (
      contains([for c in github_repository_ruleset.this[0].rules[0].required_status_checks[0].required_check : c.context if c.integration_id == null], "gate") &&
      contains([for c in github_repository_ruleset.this[0].rules[0].required_status_checks[0].required_check : c.context if c.integration_id == 15368], "build")
    )
    error_message = "each check must carry its name, and its integration_id when pinned."
  }
  assert {
    condition     = github_repository_ruleset.this[0].rules[0].required_status_checks[0].strict_required_status_checks_policy == true
    error_message = "strict_required_status_checks must be passed through."
  }
  assert {
    condition     = github_repository_ruleset.this[0].rules[0].pull_request[0].require_code_owner_review == true && github_repository_ruleset.this[0].rules[0].non_fast_forward == true
    error_message = "listing checks must keep the other ruleset defaults."
  }
}

run "labels_and_variables_come_from_maps" {
  command = plan
  variables {
    labels = {
      bug         = { color = "d73a4a", description = "Something is not working" }
      agent-ready = { name = "agent: ready", color = "0E8A16" }
    }
    actions_variables = {
      AGENT_ENABLED = "false"
      DEPLOY_REGION = "us-east1"
    }
  }

  assert {
    condition     = toset(keys(github_issue_label.this)) == toset(["bug", "agent-ready"])
    error_message = "labels must be keyed by their stable map keys."
  }
  assert {
    condition     = github_issue_label.this["bug"].name == "bug" && github_issue_label.this["bug"].color == "d73a4a" && github_issue_label.this["bug"].description == "Something is not working" && github_issue_label.this["bug"].repository == "orders-service"
    error_message = "a label's name defaults to its key."
  }
  assert {
    condition     = github_issue_label.this["agent-ready"].name == "agent: ready" && github_issue_label.this["agent-ready"].color == "0E8A16"
    error_message = "an explicit label name must be used, keyed by the stable key."
  }
  assert {
    condition     = toset(keys(github_actions_variable.this)) == toset(["AGENT_ENABLED", "DEPLOY_REGION"])
    error_message = "Actions variables must be keyed by variable name."
  }
  assert {
    condition     = github_actions_variable.this["AGENT_ENABLED"].variable_name == "AGENT_ENABLED" && github_actions_variable.this["AGENT_ENABLED"].value == "false" && github_actions_variable.this["DEPLOY_REGION"].value == "us-east1" && github_actions_variable.this["DEPLOY_REGION"].repository == "orders-service"
    error_message = "each Actions variable must carry its name and value."
  }
}

run "security_features_can_be_turned_off_for_private_repos" {
  command = plan
  variables {
    security = { secret_scanning = false, secret_scanning_push_protection = false }
  }

  assert {
    condition     = length(github_repository.this[0].security_and_analysis) == 0
    error_message = "with both features off, the module must not send security_and_analysis at all."
  }
  assert {
    condition     = github_repository_vulnerability_alerts.this[0].enabled == true
    error_message = "vulnerability alerts are free on every plan and must stay on."
  }
}

run "push_protection_alone_can_be_turned_off" {
  command = plan
  variables {
    security = { secret_scanning_push_protection = false }
  }

  assert {
    condition     = github_repository.this[0].security_and_analysis[0].secret_scanning[0].status == "enabled" && github_repository.this[0].security_and_analysis[0].secret_scanning_push_protection[0].status == "disabled"
    error_message = "scanning on with push protection off must send both statuses."
  }
}

run "advanced_security_on_combined_licence" {
  command = plan
  variables {
    security = { advanced_security = true }
  }

  assert {
    condition     = github_repository.this[0].security_and_analysis[0].advanced_security[0].status == "enabled"
    error_message = "advanced_security must be sent when set."
  }
}

run "public_repository_lets_github_decide_forking" {
  command = plan
  variables {
    visibility    = "public"
    contributions = { allow_forking = false }
  }

  assert {
    condition     = github_repository.this[0].visibility == "public" && github_repository.this[0].security_and_analysis[0].secret_scanning[0].status == "enabled"
    error_message = "a public repository keeps secret scanning on."
  }
}

run "overrides_keep_other_defaults" {
  command = plan
  variables {
    deletion_protection = { enabled = false }
    initial_commit      = { enabled = false }
    features            = { wiki = true }
    topics              = ["payments", "api"]
    default_branch_ruleset = {
      required_approving_review_count = 0
      require_code_owner_review       = false
      bypass_actors = {
        maintainers = { actor_type = "RepositoryRole", actor_id = 2, bypass_mode = "always" }
      }
    }
  }

  assert {
    condition     = github_repository.this[0].archive_on_destroy == false && github_repository.this[0].auto_init == false
    error_message = "deletion protection and the initial commit must be switchable off."
  }
  assert {
    condition     = github_repository.this[0].has_wiki == true && github_repository.this[0].has_projects == false && github_repository.this[0].topics == toset(["payments", "api"])
    error_message = "one feature override must keep the others; topics must be passed through."
  }
  assert {
    condition = (
      github_repository_ruleset.this[0].rules[0].pull_request[0].required_approving_review_count == 0 &&
      github_repository_ruleset.this[0].rules[0].pull_request[0].require_code_owner_review == false &&
      github_repository_ruleset.this[0].rules[0].non_fast_forward == true &&
      github_repository_ruleset.this[0].rules[0].deletion == true
    )
    error_message = "review overrides must apply while force-push and deletion blocks stay."
  }
  assert {
    condition     = length(github_repository_ruleset.this[0].bypass_actors) == 1 && github_repository_ruleset.this[0].bypass_actors[0].actor_type == "RepositoryRole" && github_repository_ruleset.this[0].bypass_actors[0].bypass_mode == "always"
    error_message = "bypass actors must be passed through."
  }
  assert {
    condition     = github_repository.this[0].security_and_analysis[0].secret_scanning[0].status == "enabled"
    error_message = "unrelated secure defaults must survive other overrides."
  }
}

# --- validations: every one fails on bad input (MS-2.7) ------------------------------------------

run "rejects_missing_visibility" {
  command = plan
  variables { visibility = null }
  expect_failures = [var.visibility]
}

run "rejects_unknown_visibility" {
  command = plan
  variables { visibility = "secret" }
  expect_failures = [var.visibility]
}

run "rejects_non_url_homepage" {
  command = plan
  variables { homepage_url = "www.example.com" }
  expect_failures = [var.homepage_url]
}

run "rejects_invalid_topic" {
  command = plan
  variables { topics = ["Not A Topic"] }
  expect_failures = [var.topics]
}

run "rejects_no_merge_method" {
  command = plan
  variables { merge = { allow_merge_commit = false, allow_squash_merge = false, allow_rebase_merge = false } }
  expect_failures = [var.merge]
}

run "rejects_unknown_merge_commit_title" {
  command = plan
  variables { merge = { merge_commit_title = "COMMIT_MESSAGES" } }
  expect_failures = [var.merge]
}

run "rejects_unknown_squash_message" {
  command = plan
  variables { merge = { squash_merge_commit_message = "PR_TITLE" } }
  expect_failures = [var.merge]
}

run "rejects_push_protection_without_scanning" {
  command = plan
  variables { security = { secret_scanning = false } }
  expect_failures = [var.security]
}

run "rejects_advanced_security_on_public_repo" {
  command = plan
  variables {
    visibility = "public"
    security   = { advanced_security = true }
  }
  expect_failures = [var.security]
}

run "rejects_empty_ruleset_name" {
  command = plan
  variables { default_branch_ruleset = { name = " " } }
  expect_failures = [var.default_branch_ruleset]
}

run "rejects_review_count_out_of_range" {
  command = plan
  variables { default_branch_ruleset = { required_approving_review_count = 11 } }
  expect_failures = [var.default_branch_ruleset]
}

run "rejects_empty_check_name" {
  command = plan
  variables { default_branch_ruleset = { required_status_checks = { "" = {} } } }
  expect_failures = [var.default_branch_ruleset]
}

run "rejects_unknown_bypass_actor_type" {
  command = plan
  variables { default_branch_ruleset = { bypass_actors = { admins = { actor_type = "Admin", actor_id = 1 } } } }
  expect_failures = [var.default_branch_ruleset]
}

run "rejects_unknown_bypass_mode" {
  command = plan
  variables { default_branch_ruleset = { bypass_actors = { admins = { actor_type = "RepositoryRole", actor_id = 5, bypass_mode = "sometimes" } } } }
  expect_failures = [var.default_branch_ruleset]
}

run "rejects_label_colour_with_hash" {
  command = plan
  variables { labels = { bug = { color = "#d73a4a" } } }
  expect_failures = [var.labels]
}

run "rejects_label_name_too_long" {
  command = plan
  variables { labels = { long = { name = "a-label-name-that-runs-well-past-the-fifty-character-limit", color = "d73a4a" } } }
  expect_failures = [var.labels]
}

run "rejects_duplicate_label_names" {
  command = plan
  variables {
    labels = {
      bug     = { color = "d73a4a" }
      bug-alt = { name = "Bug", color = "ee0701" }
    }
  }
  expect_failures = [var.labels]
}

run "rejects_invalid_variable_name" {
  command = plan
  variables { actions_variables = { "1ST-VALUE" = "x" } }
  expect_failures = [var.actions_variables]
}

run "rejects_reserved_variable_prefix" {
  command = plan
  variables { actions_variables = { GITHUB_SHA_OVERRIDE = "x" } }
  expect_failures = [var.actions_variables]
}

# MS-6.2: no secret values. The module has no secret input, and a variable that looks like a
# secret is rejected, because Actions variables are plain text.
run "rejects_secret_looking_variable" {
  command = plan
  variables { actions_variables = { DEPLOY_TOKEN = "x" } }
  expect_failures = [var.actions_variables]
}

run "rejects_name_too_long_for_github" {
  command = plan
  variables { name = "a-repository-name-that-is-far-too-long-for-github-to-accept-because-it-runs-past-one-hundred-chars-xy" }
  expect_failures = [github_repository.this[0]]
}
