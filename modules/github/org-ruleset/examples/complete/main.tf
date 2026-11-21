# Every input group exercised. In a root, these values live in envs/<env>.tfvars, not here.
module "ruleset" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "prod"
    component   = "github"
    repo        = "platform-github"
    labels      = { team = "platform" }
  }
  name         = "service-main"
  ruleset_name = "Services: main" # set only for a name that is not kebab-case
  enabled      = true
  target       = "branch"
  enforcement  = "active"

  conditions = {
    ref_name = {
      include = ["~DEFAULT_BRANCH", "refs/heads/release/*"]
      exclude = []
    }
    repository_name = {
      include = ["storefront", "orders-*"]
      exclude = ["orders-sandbox"]
    }
  }

  bypass_actors = {
    org-admins  = { actor_type = "OrganizationAdmin", bypass_mode = "always" } # break-glass, in the audit log
    release-app = { actor_type = "Integration", actor_id = 123456, bypass_mode = "pull_request" }
  }

  rules = {
    deletion                = true
    non_fast_forward        = true
    creation                = false
    update                  = false
    required_linear_history = true
    required_signatures     = false
    pull_request = {
      enabled                           = true
      required_approving_review_count   = 2
      require_code_owner_review         = true
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = true
      required_review_thread_resolution = true
    }
    # A pull request opened with GITHUB_TOKEN (release-please, other bots) starts no workflow, so a
    # required check never reports on it and the pull request stalls. Require only checks that
    # report on every pull request, or let those bots bypass.
    required_status_checks = {
      "ci / test" = { integration_id = 15368 } # the GitHub Actions app
    }
    strict_required_status_checks = true
  }
}
