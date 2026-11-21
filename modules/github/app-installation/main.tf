# The context call validates the shared inputs (MS-3.1). Its name and labels are not used: GitHub
# resources carry no labels, and repositories are named verbatim (ADR-0016).
module "context" {
  source = "../../_internal/context"

  context = var.context
  name    = var.name
  module  = "github-app-installation"
}

# One additive attachment per repository. github_app_installation_repositories (plural) is not
# used: its selected_repositories is authoritative, so it would remove the App from every
# repository attached outside this module (in the GitHub UI, or by another root).
resource "github_app_installation_repository" "this" {
  for_each = var.enabled ? var.repositories : toset([])

  # The provider types the id as a string; the input is a number so validation can check it.
  installation_id = tostring(var.installation_id)
  repository      = each.key
}
