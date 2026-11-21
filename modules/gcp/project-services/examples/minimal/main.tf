# The smallest correct call: one API, kept enabled if the entry is ever removed. A consumer sources
# the module by tag:
#   source = "git::https://github.com/CatylAI/terraform-modules.git//modules/gcp/project-services?ref=gcp-project-services-v0.1.0"
module "services" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "uat"
    component   = "agents"
    repo        = "agents-infra"
  }
  name       = "apis"
  project_id = "acme-uat"
  services = {
    iam = { service = "iam.googleapis.com" }
  }
}
