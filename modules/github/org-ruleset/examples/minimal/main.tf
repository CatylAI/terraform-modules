# The smallest correct call: every secure default applies. A consumer sources the module by tag:
#   source = "git::https://github.com/CatylAI/terraform-modules.git//modules/github/org-ruleset?ref=github-org-ruleset-v0.1.0"
#
# Blocks deletion of, and force pushes to, the default branch of every repository in the
# organisation. Nobody bypasses it.
module "ruleset" {
  source = "../.."

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
