# A root that creates the impersonating principal in the same apply as the account. Its member is
# unknown at plan time, so the module must not key a for_each on it. Planned by
# tests/same_apply.tftest.hcl with a mock provider, which leaves computed values unknown.
resource "google_service_account" "deployer" {
  project    = "acme-uat"
  account_id = "acme-uat-deployer"
}

module "runtime" {
  source = "../../.."

  context = {
    tenant      = "acme"
    environment = "uat"
    component   = "orders"
    repo        = "orders-service"
  }
  name       = "api"
  project_id = "acme-uat"

  impersonation = {
    deploy = { role = "roles/iam.serviceAccountUser", members = { deployer = google_service_account.deployer.member } }
  }
}
