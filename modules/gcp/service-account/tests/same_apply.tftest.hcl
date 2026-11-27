# Regression test: a principal created in the same apply (unknown at plan time) must not key a
# for_each anywhere in the module.
mock_provider "google" {}

run "plans_with_a_principal_created_in_the_same_apply" {
  command = plan

  module {
    source = "./tests/fixtures/same-apply"
  }
}
