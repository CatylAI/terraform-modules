# Regression test: values created in the same apply (unknown at plan time) must not key a
# for_each or decide a count anywhere in the module.
mock_provider "google" {
  mock_data "google_storage_project_service_account" {
    defaults = {
      email_address = "service-123456789012@gs-project-accounts.iam.gserviceaccount.com"
      member        = "serviceAccount:service-123456789012@gs-project-accounts.iam.gserviceaccount.com"
    }
  }
}

run "plans_with_members_and_topics_created_in_the_same_apply" {
  command = plan

  module {
    source = "./tests/fixtures/same-apply"
  }

  assert {
    condition     = length(module.bucket.notification_ids) == 0 || true
    error_message = "unreachable: the run passes as soon as the plan succeeds."
  }
}
