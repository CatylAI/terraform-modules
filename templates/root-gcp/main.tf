# One root, every environment. Differences live in envs/<env>.tfvars, never in this file
# (ADR-0003). Replace this example with the component's own module calls.
module "uploads" {
  source = "git::https://github.com/CatylAI/terraform-modules.git//modules/gcp/gcs-bucket?ref=gcp-gcs-bucket-v0.1.0"

  context    = local.context
  name       = "uploads"
  project_id = var.project_id
  location   = var.uploads_bucket.location

  soft_delete         = { retention_days = var.uploads_bucket.soft_delete_days }
  deletion_protection = { enabled = var.uploads_bucket.deletion_protection_on }
}
