# The smallest correct call. A consumer sources the module by tag:
#   source = "git::https://github.com/CatylAI/terraform-modules.git//modules/github/app-installation?ref=github-app-installation-v0.1.0"
module "app_installation" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "prod"
    component   = "github"
    repo        = "platform-github"
  }
  name            = "release-app"
  installation_id = 12345678
  repositories    = ["orders-service"]
}
