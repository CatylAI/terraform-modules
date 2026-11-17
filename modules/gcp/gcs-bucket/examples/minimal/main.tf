# The smallest correct call: every secure default applies. A consumer sources the module by tag:
#   source = "git::https://github.com/CatylAI/terraform-modules.git//modules/gcp/gcs-bucket?ref=gcp-gcs-bucket-v0.1.0"
module "bucket" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "uat"
    component   = "orders"
    repo        = "orders-service"
  }
  name       = "uploads"
  project_id = "acme-uat"
  location   = "US-EAST1"
}
