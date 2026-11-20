# Every input group exercised. In a root, these values live in envs/<env>.tfvars, not here.
module "repository" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "prod"
    component   = "github"
    repo        = "platform-github"
    labels      = { team = "platform" }
  }
  name         = "storefront"
  enabled      = true
  visibility   = "private"
  description  = "Storefront web application"
  homepage_url = "https://www.example.com"
  topics       = ["storefront", "web"]

  features = {
    issues      = true
    projects    = false
    wiki        = false
    discussions = true
    template    = false
  }

  merge = {
    allow_merge_commit          = false
    allow_squash_merge          = true
    allow_rebase_merge          = false
    allow_auto_merge            = true
    allow_update_branch         = true
    delete_branch_on_merge      = true
    squash_merge_commit_title   = "PR_TITLE"
    squash_merge_commit_message = "PR_BODY"
  }

  contributions = {
    allow_forking               = false
    web_commit_signoff_required = true
  }

  initial_commit = { enabled = true }

  # A private repository on the older, combined Advanced Security licence. With split licensing
  # (GitHub Secret Protection), leave advanced_security unset.
  security = {
    vulnerability_alerts            = true
    secret_scanning                 = true
    secret_scanning_push_protection = true
    advanced_security               = true
  }

  default_branch_ruleset = {
    enabled                           = true
    name                              = "protect-main"
    required_approving_review_count   = 2
    require_code_owner_review         = true
    dismiss_stale_reviews_on_push     = true
    require_last_push_approval        = true
    required_review_thread_resolution = true
    required_linear_history           = true
    required_signatures               = false
    # A pull request opened with GITHUB_TOKEN (release-please, other bots) starts no workflow, so a
    # required check never reports on it and the pull request stalls. Require only checks that
    # report on every pull request, or let those bots bypass.
    required_status_checks = {
      test = { integration_id = 15368 } # the GitHub Actions app
    }
    strict_required_status_checks = true
    bypass_actors = {
      release-app = { actor_type = "Integration", actor_id = 123456, bypass_mode = "pull_request" }
    }
  }

  labels = {
    needs-triage = { color = "d73a4a", description = "Not yet looked at" }
    agent-ready  = { name = "agent: ready", color = "0e8a16", description = "Ready for the agent to pick up" }
  }

  actions_variables = {
    AGENT_ENABLED = "false"
    DEPLOY_REGION = "us-east1"
  }

  deletion_protection = { enabled = true }
}
