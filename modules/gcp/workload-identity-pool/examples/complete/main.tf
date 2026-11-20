# Every input exercised: a GitHub Actions provider and a Kubernetes provider in one pool. In a
# root, these values live in envs/<env>.tfvars, not here.
module "wif" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "uat"
    component   = "platform"
    repo        = "platform-infra"
    labels      = { team = "platform" }
  }
  name          = "ci"
  name_override = null
  enabled       = true
  project_id    = "acme-uat"

  oidc_providers = {
    github = {
      issuer_uri = "https://token.actions.githubusercontent.com"
      attribute_mapping = {
        "google.subject"                = "assertion.sub"
        "attribute.repository"          = "assertion.repository"
        "attribute.repository_owner_id" = "assertion.repository_owner_id"
        "attribute.ref"                 = "assertion.ref"
      }
      # 123456789 stands for the acme organisation's numeric owner id.
      attribute_condition = "assertion.repository_owner_id == '123456789' && assertion.repository.startsWith('acme/')"
      allowed_audiences   = []
      disabled            = false
    }

    # A cluster whose issuer Google cannot reach (a private API server) uploads its public keys
    # instead: kubectl get --raw /openid/v1/jwks.
    k8s-cluster = {
      issuer_uri = "https://kubernetes.example.com"
      attribute_mapping = {
        "google.subject"            = "assertion.sub"
        "attribute.namespace"       = "assertion['kubernetes.io']['namespace']"
        "attribute.service_account" = "assertion['kubernetes.io']['serviceaccount']['name']"
      }
      attribute_condition = "assertion['kubernetes.io']['namespace'] == 'agents'"
      allowed_audiences   = ["acme-gcp-federation"]
      jwks_json = jsonencode({
        keys = [{
          kty = "RSA"
          alg = "RS256"
          use = "sig"
          kid = "example-key"
          n   = "replace-with-the-cluster-public-key-modulus"
          e   = "AQAB"
        }]
      })
    }
  }
}

# A principal set grants one repository, whichever workflow runs in it.
resource "google_service_account_iam_member" "deployer" {
  service_account_id = "projects/acme-uat/serviceAccounts/deployer@acme-uat.iam.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  member             = "${module.wif.principal_sets["repository"]}acme/app"
}
