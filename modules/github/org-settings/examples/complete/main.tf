# Every input group exercised. In a root, these values live in envs/<env>.tfvars, not here.
module "org_settings" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "prod"
    component   = "github"
    repo        = "platform-github"
    labels      = { team = "platform" }
  }
  name          = "org-settings"
  enabled       = true
  billing_email = "billing@example.com"

  # Set every field GitHub already shows: the provider never sends an empty value, so a field left
  # null keeps its value on GitHub and the plan shows a change on every run.
  profile = {
    display_name     = "Acme"
    description      = "Tools and services for road runners"
    email            = "contact@example.com"
    blog             = "https://www.example.com"
    company          = "Acme Corporation"
    location         = "Arizona"
    twitter_username = "acme"
  }

  member_privileges = {
    default_repository_permission = "none"
    create_repositories           = true
    create_public_repositories    = false
    create_private_repositories   = true
    create_internal_repositories  = true # GitHub Enterprise Cloud only; not sent on other plans
    fork_private_repositories     = false
    create_pages                  = true
    create_public_pages           = false
    create_private_pages          = true # private Pages need GitHub Enterprise Cloud
  }

  features = {
    organization_projects       = true
    repository_projects         = false
    web_commit_signoff_required = true
  }

  # An organisation on the older, combined Advanced Security licence.
  new_repository_security = {
    dependency_graph                = true
    dependabot_alerts               = true
    dependabot_security_updates     = true
    secret_scanning                 = true
    secret_scanning_push_protection = true
    advanced_security               = true
  }

  actions = {
    enabled_repositories    = "selected"
    selected_repository_ids = [1296269, 1300192] # numeric ids: data "github_repository" exposes repo_id
    allowed_actions         = "selected"
    github_owned_allowed    = true
    verified_allowed        = false
    patterns_allowed        = ["acme/*", "hashicorp/setup-terraform@*"]
    # Turn on only once every workflow pins actions by full commit SHA: the provider cannot turn
    # it off again.
    sha_pinning_required = true
  }

  workflow_permissions = {
    default_workflow_permissions     = "read"
    can_approve_pull_request_reviews = false
  }
}
