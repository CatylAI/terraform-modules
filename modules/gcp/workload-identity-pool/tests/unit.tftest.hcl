# The pool and provider names are computed by the API, so the mock supplies realistic values at
# plan time. Every provider instance gets the same mocked name unless a run overrides it.
mock_provider "google" {
  override_during = plan

  mock_resource "google_iam_workload_identity_pool" {
    defaults = {
      name = "projects/123456789012/locations/global/workloadIdentityPools/acme-uat-platform-ci"
    }
  }

  mock_resource "google_iam_workload_identity_pool_provider" {
    defaults = {
      name = "projects/123456789012/locations/global/workloadIdentityPools/acme-uat-platform-ci/providers/mocked"
    }
  }
}

variables {
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
      attribute_condition = "assertion.repository_owner_id == '123456789'"
    }
  }
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = google_iam_workload_identity_pool.this[0].workload_identity_pool_id == "acme-uat-platform-ci"
    error_message = "pool id must follow <tenant>-<environment>-<component>-<name>."
  }
  assert {
    condition     = google_iam_workload_identity_pool.this[0].project == "acme-uat"
    error_message = "the pool must be created in project_id."
  }
  assert {
    condition     = google_iam_workload_identity_pool.this[0].deletion_policy == "PREVENT"
    error_message = "the pool must carry deletion_policy PREVENT, so removing the module call cannot delete it."
  }
  assert {
    condition     = google_iam_workload_identity_pool.this[0].disabled == false
    error_message = "the pool must be enabled."
  }
  assert {
    condition     = google_iam_workload_identity_pool_provider.this["github"].workload_identity_pool_provider_id == "github" && google_iam_workload_identity_pool_provider.this["github"].workload_identity_pool_id == "acme-uat-platform-ci"
    error_message = "the provider id must be the map key, inside the module's pool."
  }
  assert {
    condition     = google_iam_workload_identity_pool_provider.this["github"].attribute_condition == "assertion.repository_owner_id == '123456789'"
    error_message = "the attribute condition must be passed through verbatim."
  }
  assert {
    condition     = google_iam_workload_identity_pool_provider.this["github"].attribute_mapping["attribute.repository_owner_id"] == "assertion.repository_owner_id"
    error_message = "the attribute mapping must be passed through verbatim."
  }
  assert {
    condition     = google_iam_workload_identity_pool_provider.this["github"].oidc[0].issuer_uri == "https://token.actions.githubusercontent.com"
    error_message = "the provider must be an OIDC provider on the given issuer."
  }
  assert {
    condition     = length(google_iam_workload_identity_pool_provider.this["github"].oidc[0].allowed_audiences) == 0
    error_message = "allowed_audiences must default to empty, so the token audience must be the provider's own resource name."
  }
  assert {
    condition     = google_iam_workload_identity_pool_provider.this["github"].oidc[0].jwks_json == null
    error_message = "jwks_json must default to null, so keys come from the issuer's discovery document."
  }
  assert {
    condition     = google_iam_workload_identity_pool_provider.this["github"].disabled == false
    error_message = "providers must be enabled by default."
  }
}

run "disabled_creates_nothing" {
  command = plan
  variables { enabled = false }

  assert {
    condition     = length(google_iam_workload_identity_pool.this) == 0 && length(google_iam_workload_identity_pool_provider.this) == 0
    error_message = "enabled = false must create nothing."
  }
  assert {
    condition     = output.pool_name == null && output.pool_id == null && output.provider_names == {} && output.principal_sets == {}
    error_message = "outputs must be null (or empty) when disabled."
  }
}

run "adopts_existing_name" {
  command = plan
  variables { name_override = "github-actions" }

  assert {
    condition     = google_iam_workload_identity_pool.this[0].workload_identity_pool_id == "github-actions" && google_iam_workload_identity_pool_provider.this["github"].workload_identity_pool_id == "github-actions"
    error_message = "name_override must be used verbatim as the pool id, and providers must follow it."
  }
}

run "name_prefix_replaces_computed_prefix" {
  command = plan
  variables {
    context = { tenant = "acme", environment = "uat", component = "platform", repo = "platform-infra", name_prefix = "acme-shared" }
  }

  assert {
    condition     = google_iam_workload_identity_pool.this[0].workload_identity_pool_id == "acme-shared-ci"
    error_message = "context.name_prefix must replace <tenant>-<environment>-<component>."
  }
}

run "outputs_match_documented_format" {
  command = plan

  override_resource {
    target          = google_iam_workload_identity_pool_provider.this["github"]
    override_during = plan
    values = {
      name = "projects/123456789012/locations/global/workloadIdentityPools/acme-uat-platform-ci/providers/github"
    }
  }

  assert {
    condition     = output.pool_name == "projects/123456789012/locations/global/workloadIdentityPools/acme-uat-platform-ci"
    error_message = "pool_name must be the pool's full resource name."
  }
  assert {
    condition     = output.pool_id == "acme-uat-platform-ci"
    error_message = "pool_id must be the short pool id."
  }
  assert {
    condition     = output.provider_names == { github = "projects/123456789012/locations/global/workloadIdentityPools/acme-uat-platform-ci/providers/github" }
    error_message = "provider_names must map each provider key to its full resource name."
  }
  assert {
    condition = output.principal_sets == {
      repository          = "principalSet://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/acme-uat-platform-ci/attribute.repository/"
      repository_owner_id = "principalSet://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/acme-uat-platform-ci/attribute.repository_owner_id/"
    }
    error_message = "principal_sets must hold principalSet://iam.googleapis.com/<pool name>/attribute.<name>/ for each mapped custom attribute, and nothing for google.* keys."
  }
  assert {
    condition     = "${output.principal_sets["repository"]}acme/app" == "principalSet://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/acme-uat-platform-ci/attribute.repository/acme/app"
    error_message = "appending a value to a principal_sets entry must give a valid IAM member."
  }
}

run "github_and_kubernetes_in_one_pool" {
  command = plan
  variables {
    oidc_providers = {
      github = {
        issuer_uri = "https://token.actions.githubusercontent.com"
        attribute_mapping = {
          "google.subject"                = "assertion.sub"
          "attribute.repository"          = "assertion.repository"
          "attribute.repository_owner_id" = "assertion.repository_owner_id"
        }
        attribute_condition = "assertion.repository_owner_id == '123456789' && assertion.repository == 'acme/app'"
      }
      k8s-cluster = {
        issuer_uri = "https://kubernetes.example.com"
        attribute_mapping = {
          "google.subject"            = "assertion.sub"
          "attribute.namespace"       = "assertion['kubernetes.io']['namespace']"
          "attribute.service_account" = "assertion['kubernetes.io']['serviceaccount']['name']"
        }
        attribute_condition = "assertion['kubernetes.io']['namespace'] == 'agents'"
        allowed_audiences   = ["acme-gcp-federation"]
        jwks_json           = "{\"keys\":[{\"kty\":\"RSA\",\"alg\":\"RS256\",\"use\":\"sig\",\"kid\":\"example\",\"n\":\"AQAB\",\"e\":\"AQAB\"}]}"
      }
    }
  }

  assert {
    condition     = length(google_iam_workload_identity_pool_provider.this) == 2
    error_message = "one provider per map entry."
  }
  assert {
    condition     = google_iam_workload_identity_pool_provider.this["k8s-cluster"].oidc[0].issuer_uri == "https://kubernetes.example.com" && google_iam_workload_identity_pool_provider.this["k8s-cluster"].oidc[0].allowed_audiences == tolist(["acme-gcp-federation"])
    error_message = "a Kubernetes issuer without repository_owner_id must be accepted, with its audiences."
  }
  assert {
    condition     = can(jsondecode(google_iam_workload_identity_pool_provider.this["k8s-cluster"].oidc[0].jwks_json).keys)
    error_message = "jwks_json must be passed through for an issuer Google cannot reach."
  }
  assert {
    condition     = toset(keys(output.principal_sets)) == toset(["repository", "repository_owner_id", "namespace", "service_account"])
    error_message = "principal_sets must cover the custom attributes of every provider in the pool."
  }
}

run "provider_can_be_disabled" {
  command = plan
  variables {
    oidc_providers = {
      github = {
        issuer_uri = "https://token.actions.githubusercontent.com"
        attribute_mapping = {
          "google.subject"                = "assertion.sub"
          "attribute.repository_owner_id" = "assertion.repository_owner_id"
        }
        attribute_condition = "assertion.repository_owner_id == '123456789'"
        disabled            = true
      }
    }
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.this["github"].disabled == true
    error_message = "disabled = true must disable the provider without deleting it."
  }
}

run "github_enterprise_issuer_gets_the_guard" {
  command = plan
  variables {
    oidc_providers = {
      github = {
        issuer_uri = "https://token.actions.githubusercontent.com/acme"
        attribute_mapping = {
          "google.subject"                = "assertion.sub"
          "attribute.repository_owner_id" = "assertion.repository_owner_id"
        }
        attribute_condition = "assertion.repository == 'acme/app'"
      }
    }
  }
  expect_failures = [var.oidc_providers]
}

run "rejects_empty_condition" {
  command = plan
  variables {
    oidc_providers = {
      k8s-cluster = {
        issuer_uri          = "https://kubernetes.example.com"
        attribute_mapping   = { "google.subject" = "assertion.sub" }
        attribute_condition = "   "
      }
    }
  }
  expect_failures = [var.oidc_providers]
}

run "rejects_null_condition" {
  command = plan
  variables {
    oidc_providers = {
      k8s-cluster = {
        issuer_uri          = "https://kubernetes.example.com"
        attribute_mapping   = { "google.subject" = "assertion.sub" }
        attribute_condition = null
      }
    }
  }
  expect_failures = [var.oidc_providers]
}

run "rejects_github_condition_without_owner_id" {
  command = plan
  variables {
    oidc_providers = {
      github = {
        issuer_uri = "https://token.actions.githubusercontent.com"
        attribute_mapping = {
          "google.subject"                = "assertion.sub"
          "attribute.repository"          = "assertion.repository"
          "attribute.repository_owner_id" = "assertion.repository_owner_id"
        }
        attribute_condition = "assertion.repository == 'acme/app'"
      }
    }
  }
  expect_failures = [var.oidc_providers]
}

run "rejects_github_mapping_without_owner_id" {
  command = plan
  variables {
    oidc_providers = {
      github = {
        issuer_uri = "https://token.actions.githubusercontent.com"
        attribute_mapping = {
          "google.subject"       = "assertion.sub"
          "attribute.repository" = "assertion.repository"
        }
        attribute_condition = "assertion.repository_owner_id == '123456789'"
      }
    }
  }
  expect_failures = [var.oidc_providers]
}

run "rejects_non_https_issuer" {
  command = plan
  variables {
    oidc_providers = {
      k8s-cluster = {
        issuer_uri          = "http://kubernetes.example.com"
        attribute_mapping   = { "google.subject" = "assertion.sub" }
        attribute_condition = "assertion.sub == 'system:serviceaccount:agents:runner'"
      }
    }
  }
  expect_failures = [var.oidc_providers]
}

run "rejects_mapping_without_subject" {
  command = plan
  variables {
    oidc_providers = {
      k8s-cluster = {
        issuer_uri          = "https://kubernetes.example.com"
        attribute_mapping   = { "attribute.namespace" = "assertion['kubernetes.io']['namespace']" }
        attribute_condition = "assertion['kubernetes.io']['namespace'] == 'agents'"
      }
    }
  }
  expect_failures = [var.oidc_providers]
}

run "rejects_invalid_mapping_key" {
  command = plan
  variables {
    oidc_providers = {
      k8s-cluster = {
        issuer_uri = "https://kubernetes.example.com"
        attribute_mapping = {
          "google.subject"      = "assertion.sub"
          "attribute.Namespace" = "assertion['kubernetes.io']['namespace']"
        }
        attribute_condition = "assertion['kubernetes.io']['namespace'] == 'agents'"
      }
    }
  }
  expect_failures = [var.oidc_providers]
}

run "rejects_too_many_audiences" {
  command = plan
  variables {
    oidc_providers = {
      k8s-cluster = {
        issuer_uri          = "https://kubernetes.example.com"
        attribute_mapping   = { "google.subject" = "assertion.sub" }
        attribute_condition = "assertion.sub == 'system:serviceaccount:agents:runner'"
        allowed_audiences   = [for i in range(11) : "aud-${i}"]
      }
    }
  }
  expect_failures = [var.oidc_providers]
}

run "rejects_jwks_without_keys" {
  command = plan
  variables {
    oidc_providers = {
      k8s-cluster = {
        issuer_uri          = "https://kubernetes.example.com"
        attribute_mapping   = { "google.subject" = "assertion.sub" }
        attribute_condition = "assertion.sub == 'system:serviceaccount:agents:runner'"
        jwks_json           = "not json"
      }
    }
  }
  expect_failures = [var.oidc_providers]
}

run "rejects_invalid_project_id" {
  command = plan
  variables { project_id = "Bad_Project" }
  expect_failures = [var.project_id]
}

run "rejects_pool_id_too_long" {
  command = plan
  variables {
    context = { tenant = "initech", environment = "staging", component = "platform-identity", repo = "r" }
    name    = "github-actions"
  }
  expect_failures = [google_iam_workload_identity_pool.this[0]]
}

run "rejects_reserved_pool_prefix" {
  command = plan
  variables { name_override = "gcp-federation" }
  expect_failures = [google_iam_workload_identity_pool.this[0]]
}

run "rejects_short_provider_id" {
  command = plan
  variables {
    oidc_providers = {
      k3s = {
        issuer_uri          = "https://kubernetes.example.com"
        attribute_mapping   = { "google.subject" = "assertion.sub" }
        attribute_condition = "assertion.sub == 'system:serviceaccount:agents:runner'"
      }
    }
  }
  expect_failures = [google_iam_workload_identity_pool_provider.this["k3s"]]
}

run "rejects_reserved_provider_prefix" {
  command = plan
  variables {
    oidc_providers = {
      gcp-cluster = {
        issuer_uri          = "https://kubernetes.example.com"
        attribute_mapping   = { "google.subject" = "assertion.sub" }
        attribute_condition = "assertion.sub == 'system:serviceaccount:agents:runner'"
      }
    }
  }
  expect_failures = [google_iam_workload_identity_pool_provider.this["gcp-cluster"]]
}
