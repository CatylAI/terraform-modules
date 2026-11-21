# No credentials needed: every run plans (or applies) against a mock provider.
mock_provider "github" {
  mock_resource "github_organization_ruleset" {
    defaults = {
      ruleset_id = 4242
      node_id    = "RRS_lACqUmVwb3NpdG9yec4AABCi"
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
  name   = "protect-default-branch"
  target = "branch"
  conditions = {
    repository_name = { include = ["~ALL"] }
  }
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = length(github_organization_ruleset.this) == 1
    error_message = "the ruleset must exist by default."
  }
  assert {
    condition     = github_organization_ruleset.this[0].name == "protect-default-branch" && github_organization_ruleset.this[0].target == "branch"
    error_message = "the ruleset must be named var.name verbatim, with the given target."
  }
  assert {
    condition     = github_organization_ruleset.this[0].enforcement == "active"
    error_message = "enforcement must default to active."
  }
  assert {
    condition = (
      github_organization_ruleset.this[0].conditions[0].ref_name[0].include == tolist(["~DEFAULT_BRANCH"]) &&
      length(github_organization_ruleset.this[0].conditions[0].ref_name[0].exclude) == 0
    )
    error_message = "the ref condition must default to the default branch, excluding nothing."
  }
  assert {
    condition = (
      github_organization_ruleset.this[0].conditions[0].repository_name[0].include == tolist(["~ALL"]) &&
      length(github_organization_ruleset.this[0].conditions[0].repository_name[0].exclude) == 0
    )
    error_message = "the repository condition must be the input, excluding nothing by default."
  }
  assert {
    condition     = github_organization_ruleset.this[0].rules[0].deletion == true && github_organization_ruleset.this[0].rules[0].non_fast_forward == true
    error_message = "a branch ruleset must block deletion and force pushes by default."
  }
  assert {
    condition = (
      github_organization_ruleset.this[0].rules[0].creation == false &&
      github_organization_ruleset.this[0].rules[0].update == false &&
      github_organization_ruleset.this[0].rules[0].required_linear_history == false &&
      github_organization_ruleset.this[0].rules[0].required_signatures == false
    )
    error_message = "creation, update, linear history and signatures must be off by default."
  }
  assert {
    condition     = length(github_organization_ruleset.this[0].rules[0].pull_request) == 0
    error_message = "no pull request rule unless the caller sets one."
  }
  assert {
    condition     = length(github_organization_ruleset.this[0].rules[0].required_status_checks) == 0
    error_message = "no status check is required by default (a required check stalls GITHUB_TOKEN pull requests)."
  }
  assert {
    condition     = length(github_organization_ruleset.this[0].bypass_actors) == 0
    error_message = "nobody may bypass the ruleset by default."
  }
}

run "tag_ruleset_keeps_the_deletion_and_force_push_blocks" {
  command = plan
  variables {
    name   = "protect-release-tags"
    target = "tag"
    conditions = {
      ref_name        = { include = ["refs/tags/v*"] }
      repository_name = { include = ["~ALL"], exclude = ["sandbox-*"] }
    }
  }

  assert {
    condition     = github_organization_ruleset.this[0].target == "tag" && github_organization_ruleset.this[0].conditions[0].ref_name[0].include == tolist(["refs/tags/v*"])
    error_message = "a tag ruleset must carry its target and ref patterns."
  }
  assert {
    condition     = github_organization_ruleset.this[0].conditions[0].repository_name[0].exclude == tolist(["sandbox-*"])
    error_message = "repository exclusions must be passed through."
  }
  assert {
    condition     = github_organization_ruleset.this[0].rules[0].deletion == true && github_organization_ruleset.this[0].rules[0].non_fast_forward == true
    error_message = "tags must not be deletable or movable by default."
  }
}

run "name_is_verbatim" {
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
    name = "main-branch"
  }

  assert {
    condition     = github_organization_ruleset.this[0].name == "main-branch"
    error_message = "the ruleset name must be var.name verbatim; context and name_prefix must not change it (ADR-0016)."
  }
}

run "ruleset_name_is_used_verbatim" {
  command = plan
  variables {
    name         = "release-branches"
    ruleset_name = "Release branches: protect"
  }

  assert {
    condition     = github_organization_ruleset.this[0].name == "Release branches: protect"
    error_message = "ruleset_name must name the ruleset verbatim, overriding name."
  }
}

run "disabled_creates_nothing" {
  command = plan
  variables {
    enabled = false
    rules = {
      pull_request           = {}
      required_status_checks = { "ci / test" = {} }
    }
    bypass_actors = {
      org-admins = { actor_type = "OrganizationAdmin", bypass_mode = "always" }
    }
  }

  assert {
    condition     = length(github_organization_ruleset.this) == 0
    error_message = "enabled = false must create nothing."
  }
  assert {
    condition     = output.ruleset_id == null && output.node_id == null && output.name == null
    error_message = "outputs must be null when disabled."
  }
}

run "outputs_after_apply" {
  command = apply

  assert {
    condition     = output.ruleset_id == 4242 && output.node_id == "RRS_lACqUmVwb3NpdG9yec4AABCi" && output.name == "protect-default-branch"
    error_message = "ruleset_id, node_id and name must be exported."
  }
}

run "bypass_actors_come_from_their_map" {
  command = plan
  variables {
    bypass_actors = {
      org-admins    = { actor_type = "OrganizationAdmin", bypass_mode = "always" }
      release-team  = { actor_type = "Team", actor_id = 1234567 }
      repo-admins   = { actor_type = "RepositoryRole", actor_id = 5, bypass_mode = "exempt" }
      release-robot = { actor_type = "Integration", actor_id = 98765, bypass_mode = "pull_request" }
    }
  }

  assert {
    condition     = length(github_organization_ruleset.this[0].bypass_actors) == 4
    error_message = "one bypass actor per map entry."
  }
  assert {
    condition = (
      contains([for a in github_organization_ruleset.this[0].bypass_actors : a.bypass_mode if a.actor_type == "OrganizationAdmin" && a.actor_id == null], "always") &&
      contains([for a in github_organization_ruleset.this[0].bypass_actors : a.bypass_mode if a.actor_type == "Team" && a.actor_id == 1234567], "pull_request") &&
      contains([for a in github_organization_ruleset.this[0].bypass_actors : a.bypass_mode if a.actor_type == "RepositoryRole" && a.actor_id == 5], "exempt") &&
      contains([for a in github_organization_ruleset.this[0].bypass_actors : a.bypass_mode if a.actor_type == "Integration" && a.actor_id == 98765], "pull_request")
    )
    error_message = "each actor must carry its type, id (none for OrganizationAdmin) and mode; bypass_mode defaults to pull_request."
  }
  assert {
    condition     = github_organization_ruleset.this[0].rules[0].deletion == true && github_organization_ruleset.this[0].rules[0].non_fast_forward == true
    error_message = "bypass actors must not change the rules."
  }
}

run "branch_ruleset_with_pull_request_and_required_checks" {
  command = plan
  variables {
    conditions = {
      ref_name        = { include = ["~DEFAULT_BRANCH", "refs/heads/release/*"], exclude = ["refs/heads/release/old-*"] }
      repository_name = { include = ["storefront", "orders-*"] }
    }
    rules = {
      pull_request = {}
      required_status_checks = {
        "ci / test" = {}
        build       = { integration_id = 15368 }
      }
      strict_required_status_checks = true
    }
  }

  assert {
    condition = (
      github_organization_ruleset.this[0].conditions[0].ref_name[0].include == tolist(["~DEFAULT_BRANCH", "refs/heads/release/*"]) &&
      github_organization_ruleset.this[0].conditions[0].ref_name[0].exclude == tolist(["refs/heads/release/old-*"]) &&
      github_organization_ruleset.this[0].conditions[0].repository_name[0].include == tolist(["storefront", "orders-*"])
    )
    error_message = "ref and repository patterns must be passed through in order."
  }
  assert {
    condition = (
      length(github_organization_ruleset.this[0].rules[0].pull_request) == 1 &&
      github_organization_ruleset.this[0].rules[0].pull_request[0].required_approving_review_count == 1 &&
      github_organization_ruleset.this[0].rules[0].pull_request[0].require_code_owner_review == true &&
      github_organization_ruleset.this[0].rules[0].pull_request[0].dismiss_stale_reviews_on_push == true &&
      github_organization_ruleset.this[0].rules[0].pull_request[0].require_last_push_approval == false &&
      github_organization_ruleset.this[0].rules[0].pull_request[0].required_review_thread_resolution == false
    )
    error_message = "pull_request = {} must require one approval and code-owner review, dismissing stale approvals."
  }
  assert {
    condition     = length(github_organization_ruleset.this[0].rules[0].required_status_checks) == 1 && length(github_organization_ruleset.this[0].rules[0].required_status_checks[0].required_check) == 2
    error_message = "one required_check per listed check."
  }
  assert {
    condition = (
      contains([for c in github_organization_ruleset.this[0].rules[0].required_status_checks[0].required_check : c.context if c.integration_id == null], "ci / test") &&
      contains([for c in github_organization_ruleset.this[0].rules[0].required_status_checks[0].required_check : c.context if c.integration_id == 15368], "build")
    )
    error_message = "each check must carry its context, and its integration_id when pinned."
  }
  assert {
    condition     = github_organization_ruleset.this[0].rules[0].required_status_checks[0].strict_required_status_checks_policy == true
    error_message = "strict_required_status_checks must be passed through."
  }
  assert {
    condition     = github_organization_ruleset.this[0].rules[0].deletion == true && github_organization_ruleset.this[0].rules[0].non_fast_forward == true
    error_message = "adding a pull request rule and checks must keep the deletion and force-push blocks."
  }
}

run "overrides_keep_other_defaults" {
  command = plan
  variables {
    enforcement = "evaluate"
    rules = {
      deletion                = false
      required_linear_history = true
      pull_request = {
        required_approving_review_count = 0
        require_code_owner_review       = false
      }
    }
  }

  assert {
    condition     = github_organization_ruleset.this[0].enforcement == "evaluate"
    error_message = "enforcement must be passed through."
  }
  assert {
    condition = (
      github_organization_ruleset.this[0].rules[0].deletion == false &&
      github_organization_ruleset.this[0].rules[0].non_fast_forward == true &&
      github_organization_ruleset.this[0].rules[0].required_linear_history == true
    )
    error_message = "one rule override must keep the other rule defaults."
  }
  assert {
    condition = (
      github_organization_ruleset.this[0].rules[0].pull_request[0].required_approving_review_count == 0 &&
      github_organization_ruleset.this[0].rules[0].pull_request[0].require_code_owner_review == false &&
      github_organization_ruleset.this[0].rules[0].pull_request[0].dismiss_stale_reviews_on_push == true
    )
    error_message = "one pull request override must keep the other pull request defaults."
  }
}

# A ruleset that only requires a check (deletion and force pushes left to another ruleset), as an
# adopted ruleset may be.
run "checks_only_ruleset" {
  command = plan
  variables {
    rules = {
      deletion               = false
      non_fast_forward       = false
      required_status_checks = { "ci / test" = {} }
    }
  }

  assert {
    condition = (
      github_organization_ruleset.this[0].rules[0].deletion == false &&
      github_organization_ruleset.this[0].rules[0].non_fast_forward == false &&
      length(github_organization_ruleset.this[0].rules[0].pull_request) == 0 &&
      length(github_organization_ruleset.this[0].rules[0].required_status_checks) == 1
    )
    error_message = "the deletion and force-push blocks must be switchable off, leaving only the required check."
  }
}

run "pull_request_can_be_switched_off" {
  command = plan
  variables {
    rules = { pull_request = { enabled = false } }
  }

  assert {
    condition     = length(github_organization_ruleset.this[0].rules[0].pull_request) == 0
    error_message = "pull_request.enabled = false must remove the pull request rule."
  }
}

# --- validations: every one fails on bad input (MS-2.7) ------------------------------------------

run "rejects_repository_target" {
  command = plan
  variables { target = "repository" }
  expect_failures = [var.target]
}

run "rejects_push_target" {
  command = plan
  variables { target = "push" }
  expect_failures = [var.target]
}

run "rejects_missing_target" {
  command = plan
  variables { target = null }
  expect_failures = [var.target]
}

run "rejects_unknown_enforcement" {
  command = plan
  variables { enforcement = "enforced" }
  expect_failures = [var.enforcement]
}

run "rejects_blank_ruleset_name" {
  command = plan
  variables { ruleset_name = "  " }
  expect_failures = [var.ruleset_name]
}

run "rejects_ruleset_name_too_long" {
  command = plan
  variables { ruleset_name = "A ruleset name that is far too long for GitHub to accept because it runs past one hundred characters in all" }
  expect_failures = [var.ruleset_name]
}

run "rejects_empty_repository_include" {
  command = plan
  variables {
    conditions = { repository_name = { include = [] } }
  }
  expect_failures = [var.conditions]
}

run "rejects_empty_ref_include" {
  command = plan
  variables {
    conditions = {
      ref_name        = { include = [] }
      repository_name = { include = ["~ALL"] }
    }
  }
  expect_failures = [var.conditions]
}

run "rejects_blank_pattern" {
  command = plan
  variables {
    conditions = { repository_name = { include = ["~ALL"], exclude = [" "] } }
  }
  expect_failures = [var.conditions]
}

run "rejects_unknown_bypass_actor_type" {
  command = plan
  variables { bypass_actors = { someone = { actor_type = "User", actor_id = 1 } } }
  expect_failures = [var.bypass_actors]
}

run "rejects_unknown_bypass_mode" {
  command = plan
  variables { bypass_actors = { admins = { actor_type = "RepositoryRole", actor_id = 5, bypass_mode = "sometimes" } } }
  expect_failures = [var.bypass_actors]
}

run "rejects_actor_id_on_id_less_actor" {
  command = plan
  variables { bypass_actors = { org-admins = { actor_type = "OrganizationAdmin", actor_id = 1, bypass_mode = "always" } } }
  expect_failures = [var.bypass_actors]
}

run "rejects_missing_actor_id" {
  command = plan
  variables { bypass_actors = { release-team = { actor_type = "Team" } } }
  expect_failures = [var.bypass_actors]
}

run "rejects_review_count_out_of_range" {
  command = plan
  variables { rules = { pull_request = { required_approving_review_count = 11 } } }
  expect_failures = [var.rules]
}

run "rejects_fractional_review_count" {
  command = plan
  variables { rules = { pull_request = { required_approving_review_count = 1.5 } } }
  expect_failures = [var.rules]
}

run "rejects_empty_check_context" {
  command = plan
  variables { rules = { required_status_checks = { " " = {} } } }
  expect_failures = [var.rules]
}

run "rejects_ruleset_with_no_rules" {
  command = plan
  variables { rules = { deletion = false, non_fast_forward = false } }
  expect_failures = [var.rules]
}

run "rejects_name_too_long_for_github" {
  command = plan
  variables { name = "a-ruleset-name-that-is-far-too-long-for-github-to-accept-because-it-runs-past-one-hundred-characters-xyz" }
  expect_failures = [github_organization_ruleset.this[0]]
}
