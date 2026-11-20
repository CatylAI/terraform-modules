# The smallest correct call: one GitHub Actions provider, trusted only for one owner. A consumer
# sources the module by tag:
#   source = "git::https://github.com/CatylAI/terraform-modules.git//modules/gcp/workload-identity-pool?ref=gcp-workload-identity-pool-v0.1.0"
module "wif" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "uat"
    component   = "platform"
    repo        = "platform-infra"
  }
  name       = "ci"
  project_id = "acme-uat"

  oidc_providers = {
    github = {
      issuer_uri = "https://token.actions.githubusercontent.com"
      attribute_mapping = {
        "google.subject"                = "assertion.sub"
        "attribute.repository"          = "assertion.repository"
        "attribute.repository_owner_id" = "assertion.repository_owner_id"
      }
      # 123456789 stands for the GitHub owner's numeric id (gh api orgs/<org> --jq .id).
      attribute_condition = "assertion.repository_owner_id == '123456789'"
    }
  }
}
