# The smallest correct call: every secure default applies, and nobody can impersonate the account.
# A consumer sources the module by tag:
#   source = "git::https://github.com/CatylAI/terraform-modules.git//modules/gcp/service-account?ref=gcp-service-account-v0.1.0"
module "service_account" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "uat"
    component   = "orders"
    repo        = "orders-service"
  }
  name       = "api"
  project_id = "acme-uat"
}
