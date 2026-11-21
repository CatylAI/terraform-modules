# Every input group exercised. In a root, these values live in envs/<env>.tfvars, not here.
# Required reviewers work on a public repository, or on any repository under GitHub Enterprise.
data "github_user" "release_manager" {
  username = "octocat"
}

data "github_team" "release" {
  slug = "release-managers"
}

module "environment" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "prod"
    component   = "delivery"
    repo        = "delivery-stack"
  }
  name             = "storefront-production"
  enabled          = true
  repository       = "storefront"
  environment_name = "production"

  # Self-review is always blocked when reviewers are set. Ids, not logins: the data sources
  # resolve them, and return them as strings.
  reviewers = {
    users = [tonumber(data.github_user.release_manager.id)]
    teams = [tonumber(data.github_team.release.id)]
  }

  # Reviewers are set, so the policy may use wildcards and tags. Without reviewers, only exact
  # branch names are accepted.
  deployment_branch_policy = {
    branches = ["main", "release/*"]
    tags     = ["v*"]
  }

  admin_bypass = { enabled = false }

  variables = {
    DEPLOY_REGION = "us-east1"
    SITE_URL      = "https://www.example.com"
  }
}
