# API enablements carry no name and no labels. The context call still validates the inputs and
# identifies the module (MS-3.1); its name and labels have nothing to attach to.
module "context" {
  source = "../../_internal/context"

  context = var.context
  name    = var.name
  module  = "gcp-project-services"
}

resource "google_project_service" "this" {
  for_each = var.enabled ? var.services : {}

  project = var.project_id
  service = each.value.service

  # The provider defaults disable_on_destroy to true, so deleting a map entry would switch the
  # API off under whatever still calls it. Off by default here; disabling is a per-entry choice.
  disable_on_destroy         = each.value.disable_on_destroy
  disable_dependent_services = each.value.disable_dependent_services
}
