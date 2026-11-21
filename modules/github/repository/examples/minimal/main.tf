# The smallest correct call: every secure default applies. A consumer sources the module by tag:
#   source = "git::https://github.com/CatylAI/terraform-modules.git//modules/github/repository?ref=github-repository-v0.1.0"
module "repository" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "prod"
    component   = "github"
    repo        = "platform-github"
  }
  name       = "orders-service"
  visibility = "private"

  # A private repository on a plan without GitHub Secret Protection: turn both off explicitly.
  # Public repositories, and private ones on a plan that includes it, keep the defaults.
  security = {
    secret_scanning                 = false
    secret_scanning_push_protection = false
  }
}
