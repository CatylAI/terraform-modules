# google_project_service has no labels, no name and no IAM input, so MS-9.1 item 4 is covered by
# the context call (name validation and the module label), and no MS-6 invariant applies: the
# module takes no IAM members, no roles and no secret values.
mock_provider "google" {}

variables {
  context = {
    tenant      = "acme"
    environment = "uat"
    component   = "agents"
    repo        = "agents-infra"
  }
  name       = "apis"
  project_id = "acme-uat"
  services = {
    aiplatform = { service = "aiplatform.googleapis.com" }
  }
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = length(google_project_service.this) == 1 && google_project_service.this["aiplatform"].service == "aiplatform.googleapis.com" && google_project_service.this["aiplatform"].project == "acme-uat"
    error_message = "one API enablement per entry, in the given project."
  }
  assert {
    condition     = google_project_service.this["aiplatform"].disable_on_destroy == false
    error_message = "removing an entry must leave the API enabled: disable_on_destroy must default to false."
  }
  assert {
    condition     = google_project_service.this["aiplatform"].disable_dependent_services == false
    error_message = "disable_dependent_services must default to false."
  }
  assert {
    condition     = output.services == { aiplatform = "aiplatform.googleapis.com" }
    error_message = "services output must map each key to its service name."
  }
}

run "default_keeps_every_entry_enabled" {
  command = plan
  variables {
    services = {
      aiplatform           = { service = "aiplatform.googleapis.com" }
      iam                  = { service = "iam.googleapis.com" }
      iamcredentials       = { service = "iamcredentials.googleapis.com" }
      sts                  = { service = "sts.googleapis.com" }
      cloudresourcemanager = { service = "cloudresourcemanager.googleapis.com" }
    }
  }

  assert {
    condition     = length(google_project_service.this) == 5
    error_message = "one API enablement per entry."
  }
  assert {
    condition     = alltrue([for s in values(google_project_service.this) : s.disable_on_destroy == false && s.disable_dependent_services == false])
    error_message = "every entry must default to disable_on_destroy = false and disable_dependent_services = false."
  }
  assert {
    condition     = sort(values(output.services)) == sort(["aiplatform.googleapis.com", "iam.googleapis.com", "iamcredentials.googleapis.com", "sts.googleapis.com", "cloudresourcemanager.googleapis.com"])
    error_message = "services output must list every enabled service."
  }
}

run "per_entry_disable_override" {
  command = plan
  variables {
    services = {
      iam        = { service = "iam.googleapis.com" }
      scratch    = { service = "translate.googleapis.com", disable_on_destroy = true }
      cascade    = { service = "pubsub.googleapis.com", disable_on_destroy = true, disable_dependent_services = true }
      monitoring = { service = "monitoring.googleapis.com" }
    }
  }

  assert {
    condition     = google_project_service.this["scratch"].disable_on_destroy == true && google_project_service.this["scratch"].disable_dependent_services == false
    error_message = "an explicit disable_on_destroy must apply to its entry only, keeping disable_dependent_services off."
  }
  assert {
    condition     = google_project_service.this["cascade"].disable_on_destroy == true && google_project_service.this["cascade"].disable_dependent_services == true
    error_message = "disable_dependent_services must apply when explicitly set with disable_on_destroy."
  }
  assert {
    condition     = google_project_service.this["iam"].disable_on_destroy == false && google_project_service.this["monitoring"].disable_on_destroy == false
    error_message = "an override on one entry must not change the others."
  }
}

run "disabled_creates_nothing" {
  command = plan
  variables { enabled = false }

  assert {
    condition     = length(google_project_service.this) == 0
    error_message = "enabled = false must create nothing."
  }
  assert {
    condition     = output.services == {}
    error_message = "services output must be empty when disabled."
  }
}

run "naming_and_labels" {
  command = plan

  assert {
    condition     = module.context.name == "acme-uat-agents-apis"
    error_message = "the logical name must follow <tenant>-<environment>-<component>-<name>."
  }
  assert {
    condition     = module.context.labels["module"] == "gcp-project-services" && module.context.labels["managed-by"] == "terraform"
    error_message = "the context call must identify this module."
  }
}

run "rejects_service_without_googleapis_suffix" {
  command = plan
  variables { services = { bad = { service = "aiplatform" } } }
  expect_failures = [var.services]
}

run "rejects_service_on_other_domain" {
  command = plan
  variables { services = { bad = { service = "aiplatform.googleapis.com.example.com" } } }
  expect_failures = [var.services]
}

run "rejects_duplicate_service" {
  command = plan
  variables {
    services = {
      iam       = { service = "iam.googleapis.com" }
      iam-again = { service = "iam.googleapis.com" }
    }
  }
  expect_failures = [var.services]
}

run "rejects_dependent_disable_without_disable_on_destroy" {
  command = plan
  variables { services = { iam = { service = "iam.googleapis.com", disable_dependent_services = true } } }
  expect_failures = [var.services]
}

run "rejects_invalid_project_id" {
  command = plan
  variables { project_id = "Bad_Project" }
  expect_failures = [var.project_id]
}
