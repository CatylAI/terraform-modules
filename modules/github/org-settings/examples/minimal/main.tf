# The smallest correct call: every secure default applies. A consumer sources the module by tag:
#   source = "git::https://github.com/CatylAI/terraform-modules.git//modules/github/org-settings?ref=github-org-settings-v0.1.0"
#
# The settings apply to the github provider's owner, which must be an organisation.
module "org_settings" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "prod"
    component   = "github"
    repo        = "platform-github"
  }
  name          = "org-settings"
  billing_email = "billing@example.com"

  # An organisation without GitHub Secret Protection: secret scanning on new private repositories
  # needs it, so turn both off explicitly. Organisations with it keep the defaults.
  new_repository_security = {
    secret_scanning                 = false
    secret_scanning_push_protection = false
  }
}
