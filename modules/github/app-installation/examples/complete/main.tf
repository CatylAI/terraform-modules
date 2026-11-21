# Every input exercised. In a root, these values live in envs/<env>.tfvars, not here.
module "app_installation" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "prod"
    component   = "github"
    repo        = "platform-github"
    labels      = { team = "platform" } # validated, not applied: GitHub has no labels
  }
  name = "release-app"

  # One optional variable drives both: no installation id, nothing attached.
  enabled         = var.release_app_installation_id != null
  installation_id = var.release_app_installation_id

  # Names verbatim, without the owner. Names that are not kebab-case are accepted.
  repositories = ["orders-service", "billing-api", ".github"]
}
