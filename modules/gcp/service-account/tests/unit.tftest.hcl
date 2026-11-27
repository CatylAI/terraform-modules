# The provider validates IAM member syntax, and the outputs are read at plan time, so the service
# account's computed attributes get realistic values during plan rather than the mock's random
# strings (or unknowns).
mock_provider "google" {
  mock_resource "google_service_account" {
    override_during = plan
    defaults = {
      email     = "acme-uat-orders-api@acme-uat.iam.gserviceaccount.com"
      member    = "serviceAccount:acme-uat-orders-api@acme-uat.iam.gserviceaccount.com"
      name      = "projects/acme-uat/serviceAccounts/acme-uat-orders-api@acme-uat.iam.gserviceaccount.com"
      unique_id = "123456789012345678901"
    }
  }
}

variables {
  context = {
    tenant      = "acme"
    environment = "uat"
    component   = "orders"
    repo        = "orders-service"
  }
  name       = "api"
  project_id = "acme-uat"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = google_service_account.this[0].account_id == "acme-uat-orders-api"
    error_message = "account id must follow <tenant>-<environment>-<component>-<name>."
  }
  assert {
    condition     = google_service_account.this[0].project == "acme-uat"
    error_message = "the account must be created in project_id."
  }
  assert {
    condition     = google_service_account.this[0].deletion_policy == "PREVENT"
    error_message = "the account must be deletion-protected by default."
  }
  assert {
    condition     = google_service_account.this[0].display_name == null && google_service_account.this[0].description == null
    error_message = "display name and description must be unset by default."
  }
  assert {
    condition     = google_service_account.this[0].disabled == null || google_service_account.this[0].disabled == false
    error_message = "the account must be enabled by default."
  }
  assert {
    condition     = length(google_project_iam_member.this) == 0
    error_message = "no project role bindings by default."
  }
  assert {
    condition     = length(google_service_account_iam_member.impersonation) == 0
    error_message = "nobody may impersonate the account by default; token creation exists only through an explicit entry."
  }
}

run "outputs" {
  command = plan

  assert {
    condition     = output.email == "acme-uat-orders-api@acme-uat.iam.gserviceaccount.com"
    error_message = "email output must be the account's email."
  }
  assert {
    condition     = output.member == "serviceAccount:${output.email}"
    error_message = "member output must be serviceAccount:<email>."
  }
  assert {
    condition     = output.unique_id == "123456789012345678901"
    error_message = "unique_id output must be the account's unique id."
  }
  assert {
    condition     = output.name == "projects/acme-uat/serviceAccounts/${output.email}"
    error_message = "name output must be the account's full resource name."
  }
}

run "disabled_creates_nothing" {
  command = plan
  variables {
    enabled       = false
    project_roles = { aiplatform = { role = "roles/aiplatform.user" } }
    impersonation = { ci = { role = "roles/iam.serviceAccountTokenCreator", members = { ci = "group:ci@example.com" } } }
  }

  assert {
    condition     = length(google_service_account.this) == 0 && length(google_project_iam_member.this) == 0 && length(google_service_account_iam_member.impersonation) == 0
    error_message = "enabled = false must create nothing."
  }
  assert {
    condition     = output.email == null && output.member == null && output.unique_id == null && output.name == null
    error_message = "every output must be null when disabled."
  }
}

run "adopts_existing_name" {
  command = plan
  variables { name_override = "legacy-orders-sa" }

  assert {
    condition     = google_service_account.this[0].account_id == "legacy-orders-sa"
    error_message = "name_override must be used verbatim as the account id."
  }
}

run "name_prefix_replaces_computed_prefix" {
  command = plan
  variables {
    context = { tenant = "acme", environment = "uat", component = "orders", repo = "orders-service", name_prefix = "ord" }
  }

  assert {
    condition     = google_service_account.this[0].account_id == "ord-api"
    error_message = "context.name_prefix must replace <tenant>-<environment>-<component>."
  }
}

run "complete_configuration" {
  command = plan
  variables {
    display_name        = "Orders API"
    description         = "Runtime identity of the orders API."
    deletion_protection = { enabled = false }
    project_roles = {
      aiplatform = { role = "roles/aiplatform.user" }
      metrics    = { role = "roles/monitoring.viewer" }
      custom     = { role = "projects/acme-uat/roles/ordersReader" }
    }
    impersonation = {
      github = {
        role    = "roles/iam.workloadIdentityUser"
        members = { orders-service = "principalSet://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github/attribute.repository/acme/orders-service" }
      }
      deployer = {
        role    = "roles/iam.serviceAccountUser"
        members = { deployer = "serviceAccount:deployer@acme-uat.iam.gserviceaccount.com" }
      }
      oncall = {
        role    = "roles/iam.serviceAccountTokenCreator"
        members = { oncall = "group:oncall@example.com", alice = "user:alice@example.com" }
      }
    }
  }

  assert {
    condition     = google_service_account.this[0].display_name == "Orders API" && google_service_account.this[0].description == "Runtime identity of the orders API."
    error_message = "display name and description must be passed through."
  }
  assert {
    condition     = google_service_account.this[0].deletion_policy == "DELETE"
    error_message = "deletion protection must be switchable off for scratch environments."
  }
  assert {
    condition     = length(google_project_iam_member.this) == 3 && google_project_iam_member.this["aiplatform"].role == "roles/aiplatform.user" && google_project_iam_member.this["custom"].role == "projects/acme-uat/roles/ordersReader"
    error_message = "one additive project IAM member per project_roles entry, keyed by the entry name."
  }
  assert {
    condition     = alltrue([for b in google_project_iam_member.this : b.project == "acme-uat" && b.member == "serviceAccount:acme-uat-orders-api@acme-uat.iam.gserviceaccount.com"])
    error_message = "project roles must be granted to this account in project_id."
  }
  assert {
    condition     = length(google_service_account_iam_member.impersonation) == 4 && contains(keys(google_service_account_iam_member.impersonation), "oncall/oncall")
    error_message = "one additive IAM member per impersonation member, keyed <binding>/<member name>."
  }
  assert {
    condition     = alltrue([for b in google_service_account_iam_member.impersonation : b.service_account_id == "projects/acme-uat/serviceAccounts/acme-uat-orders-api@acme-uat.iam.gserviceaccount.com"])
    error_message = "impersonation bindings must be on this account."
  }
  assert {
    condition     = google_service_account_iam_member.impersonation["github/orders-service"].role == "roles/iam.workloadIdentityUser"
    error_message = "each impersonation member must carry its entry's role."
  }
}

run "token_creation_only_when_requested" {
  command = plan
  variables {
    project_roles = { aiplatform = { role = "roles/aiplatform.user" } }
    impersonation = { deployer = { role = "roles/iam.serviceAccountUser", members = { deployer = "serviceAccount:deployer@acme-uat.iam.gserviceaccount.com" } } }
  }

  assert {
    condition     = alltrue([for b in google_service_account_iam_member.impersonation : b.role != "roles/iam.serviceAccountTokenCreator"])
    error_message = "token creation must not be granted unless an impersonation entry asks for it."
  }
  assert {
    condition     = alltrue([for b in google_project_iam_member.this : b.role != "roles/iam.serviceAccountTokenCreator"])
    error_message = "the module must not add token creation through project roles on its own."
  }
}

run "rejects_basic_role_in_project_roles" {
  command = plan
  variables { project_roles = { admin = { role = "roles/editor" } } }
  expect_failures = [var.project_roles]
}

run "rejects_owner_role_in_project_roles" {
  command = plan
  variables { project_roles = { admin = { role = "roles/owner" } } }
  expect_failures = [var.project_roles]
}

run "rejects_malformed_project_role" {
  command = plan
  variables { project_roles = { bad = { role = "aiplatform.user" } } }
  expect_failures = [var.project_roles]
}

run "rejects_basic_role_in_impersonation" {
  command = plan
  variables { impersonation = { admins = { role = "roles/viewer", members = { admins = "group:admins@example.com" } } } }
  expect_failures = [var.impersonation]
}

run "rejects_non_impersonation_role" {
  command = plan
  variables { impersonation = { keys = { role = "roles/iam.serviceAccountKeyAdmin", members = { admins = "group:admins@example.com" } } } }
  expect_failures = [var.impersonation]
}

run "rejects_all_users" {
  command = plan
  variables { impersonation = { everyone = { role = "roles/iam.serviceAccountTokenCreator", members = { everyone = "allUsers" } } } }
  expect_failures = [var.impersonation]
}

run "rejects_all_authenticated_users" {
  command = plan
  variables { impersonation = { everyone = { role = "roles/iam.serviceAccountUser", members = { ci = "group:ci@example.com", everyone = "allAuthenticatedUsers" } } } }
  expect_failures = [var.impersonation]
}

run "rejects_empty_impersonation_members" {
  command = plan
  variables { impersonation = { nobody = { role = "roles/iam.serviceAccountUser", members = {} } } }
  expect_failures = [var.impersonation]
}

run "rejects_invalid_project_id" {
  command = plan
  variables { project_id = "Bad_Project" }
  expect_failures = [var.project_id]
}

run "rejects_long_display_name" {
  command = plan
  variables { display_name = "This display name runs well past the one hundred character limit that the IAM API enforces on accounts" }
  expect_failures = [var.display_name]
}

run "rejects_long_description" {
  command = plan
  variables { description = "This description is deliberately far too long for a service account. The IAM API caps descriptions at 256 bytes, and the module checks the length at plan time so the mistake surfaces in review rather than as an API error during apply. This sentence pushes it past." }
  expect_failures = [var.description]
}

run "rejects_account_id_too_long" {
  command = plan
  variables { name = "a-long-instance-name" }
  expect_failures = [google_service_account.this[0]]
}

run "rejects_account_id_too_short" {
  command = plan
  variables {
    context = { tenant = "acme", environment = "uat", component = "orders", repo = "orders-service", name_prefix = "a" }
    name    = "b"
  }
  expect_failures = [google_service_account.this[0]]
}

run "rejects_invalid_name_override" {
  command = plan
  variables { name_override = "Legacy_SA" }
  expect_failures = [google_service_account.this[0]]
}
