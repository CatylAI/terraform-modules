# Every input exercised. In a root, these values live in envs/<env>.tfvars, not here.
module "services" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "uat"
    component   = "agents"
    repo        = "agents-infra"
    labels      = { team = "platform" }
  }
  name       = "apis"
  enabled    = true
  project_id = "acme-uat"

  services = {
    # Removing any of these entries stops managing the API and leaves it enabled (the default).
    aiplatform           = { service = "aiplatform.googleapis.com" }
    iam                  = { service = "iam.googleapis.com" }
    iamcredentials       = { service = "iamcredentials.googleapis.com" }
    sts                  = { service = "sts.googleapis.com" }
    cloudresourcemanager = { service = "cloudresourcemanager.googleapis.com" }

    # Explicit opt-in: removing this entry disables the API. Nothing else in the project depends
    # on it, so disable_dependent_services stays off and a dependent API would make the disable fail.
    translate = { service = "translate.googleapis.com", disable_on_destroy = true, disable_dependent_services = false }
  }
}
