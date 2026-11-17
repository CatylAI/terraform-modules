locals {
  context = {
    tenant      = var.tenant
    environment = var.environment
    component   = var.component
    repo        = var.repo
  }

  labels = {
    "managed-by" = "terraform"
    tenant       = var.tenant
    environment  = var.environment
    component    = var.component
    repo         = lower(replace(var.repo, "/[^A-Za-z0-9_-]/", "-"))
  }
}
