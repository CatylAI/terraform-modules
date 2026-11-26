# Every input group exercised. In a root, these values live in envs/<env>.tfvars, not here.
module "service_account" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "uat"
    component   = "orders"
    repo        = "orders-service"
    labels      = { team = "platform" }
  }
  name          = "deploy"
  name_override = null
  project_id    = "acme-uat"
  display_name  = "Orders deployer"
  description   = "Identity GitHub Actions uses to deploy the orders service."

  deletion_protection = { enabled = true }

  project_roles = {
    aiplatform = { role = "roles/aiplatform.user" }
    metrics    = { role = "roles/monitoring.viewer" }
    run-admin  = { role = "roles/run.developer" }
  }

  impersonation = {
    # GitHub Actions signs in through Workload Identity Federation; no key exists.
    github-actions = {
      role    = "roles/iam.workloadIdentityUser"
      members = ["principalSet://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github/attribute.repository/acme/orders-service"]
    }
    # Token creation is never implied; this entry grants it explicitly, to a group only.
    break-glass = {
      role    = "roles/iam.serviceAccountTokenCreator"
      members = ["group:platform-oncall@example.com"]
    }
    scheduler = {
      role    = "roles/iam.serviceAccountUser"
      members = ["serviceAccount:scheduler@acme-uat.iam.gserviceaccount.com"]
    }
  }
}
