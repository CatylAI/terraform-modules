# The smallest correct call: no reviewers, so only protected branches may deploy, and approval
# happens at the pull request that changes the protected branch. This works on a private
# repository on any plan. A consumer sources the module by tag:
#   source = "git::https://github.com/CatylAI/terraform-modules.git//modules/github/repository-environment?ref=github-repository-environment-v0.1.0"
module "environment" {
  source = "../.."

  context = {
    tenant      = "acme"
    environment = "prod"
    component   = "delivery"
    repo        = "delivery-stack"
  }
  name             = "orders-production"
  repository       = "orders-service"
  environment_name = "production"
}
