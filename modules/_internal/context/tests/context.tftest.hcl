variables {
  context = {
    tenant      = "acme"
    environment = "uat"
    component   = "orders"
    repo        = "orders-service"
  }
  name   = "uploads"
  module = "gcp-gcs-bucket"
}

run "computes_name_and_labels" {
  command = plan

  assert {
    condition     = output.name == "acme-uat-orders-uploads"
    error_message = "name must be <tenant>-<environment>-<component>-<name>."
  }

  assert {
    condition     = output.name_prefix == "acme-uat-orders"
    error_message = "name_prefix must be <tenant>-<environment>-<component>."
  }

  assert {
    condition = output.labels == {
      "managed-by" = "terraform"
      tenant       = "acme"
      environment  = "uat"
      component    = "orders"
      repo         = "orders-service"
      module       = "gcp-gcs-bucket"
    }
    error_message = "labels must be exactly the reserved keys when the caller adds none."
  }
}

run "name_override_is_verbatim" {
  command = plan
  variables { name_override = "legacy-bucket-name" }

  assert {
    condition     = output.name == "legacy-bucket-name"
    error_message = "name_override must replace the computed name verbatim."
  }

  assert {
    condition     = output.labels["environment"] == "uat"
    error_message = "labels must still apply when name_override is set."
  }
}

run "merges_caller_labels" {
  command = plan
  variables {
    context = {
      tenant      = "acme"
      environment = "prod"
      component   = "web"
      repo        = "storefront"
      labels      = { team = "platform", cost-center = "rd" }
    }
  }

  assert {
    condition     = output.labels["team"] == "platform" && output.labels["cost-center"] == "rd" && output.labels["environment"] == "prod"
    error_message = "caller labels must be merged alongside the reserved keys."
  }
}

run "folds_repo_to_label_rules" {
  command = plan
  variables {
    context = {
      tenant      = "acme"
      environment = "uat"
      component   = "orders"
      repo        = "Acme.Orders"
    }
  }

  assert {
    condition     = output.labels["repo"] == "acme-orders"
    error_message = "repo label must be lowercased with invalid characters replaced by '-'."
  }
}

run "rejects_unknown_environment" {
  command = plan
  variables {
    context = { tenant = "acme", environment = "production", component = "orders", repo = "orders-service" }
  }
  expect_failures = [var.context]
}

run "rejects_non_kebab_tenant" {
  command = plan
  variables {
    context = { tenant = "Acme Corp", environment = "uat", component = "orders", repo = "orders-service" }
  }
  expect_failures = [var.context]
}

run "accepts_any_kebab_tenant" {
  command = plan
  variables {
    context = { tenant = "globex", environment = "uat", component = "orders", repo = "orders-service" }
  }

  assert {
    condition     = output.name == "globex-uat-orders-uploads"
    error_message = "the module must not restrict tenants; that is the root's policy."
  }
}

run "custom_environment_vocabulary" {
  command = plan
  variables {
    context = { tenant = "acme", environment = "qa", component = "orders", repo = "orders-service", allowed_environments = ["qa", "production"] }
  }

  assert {
    condition     = output.labels["environment"] == "qa"
    error_message = "a caller-supplied environment vocabulary must be honoured."
  }
}

run "custom_vocabulary_replaces_default" {
  command = plan
  variables {
    context = { tenant = "acme", environment = "uat", component = "orders", repo = "orders-service", allowed_environments = ["qa", "production"] }
  }
  expect_failures = [var.context]
}

run "name_prefix_override" {
  command = plan
  variables {
    context = { tenant = "acme", environment = "uat", component = "orders", repo = "orders-service", name_prefix = "ord-uat" }
  }

  assert {
    condition     = output.name == "ord-uat-uploads" && output.labels["tenant"] == "acme"
    error_message = "name_prefix must replace the computed prefix and leave labels alone."
  }
}

run "rejects_invalid_name_prefix" {
  command = plan
  variables {
    context = { tenant = "acme", environment = "uat", component = "orders", repo = "orders-service", name_prefix = "Ord_UAT" }
  }
  expect_failures = [var.context]
}

run "rejects_non_kebab_component" {
  command = plan
  variables {
    context = { tenant = "acme", environment = "uat", component = "Orders_API", repo = "orders-service" }
  }
  expect_failures = [var.context]
}

run "rejects_invalid_repo" {
  command = plan
  variables {
    context = { tenant = "acme", environment = "uat", component = "orders", repo = "has space" }
  }
  expect_failures = [var.context]
}

run "rejects_invalid_label_key" {
  command = plan
  variables {
    context = { tenant = "acme", environment = "uat", component = "orders", repo = "orders-service", labels = { Team = "platform" } }
  }
  expect_failures = [var.context]
}

run "rejects_invalid_label_value" {
  command = plan
  variables {
    context = { tenant = "acme", environment = "uat", component = "orders", repo = "orders-service", labels = { team = "Platform Team" } }
  }
  expect_failures = [var.context]
}

run "rejects_reserved_label_key" {
  command = plan
  variables {
    context = { tenant = "acme", environment = "uat", component = "orders", repo = "orders-service", labels = { environment = "prod" } }
  }
  expect_failures = [var.context]
}

run "rejects_non_kebab_name" {
  command = plan
  variables { name = "Uploads_Bucket" }
  expect_failures = [var.name]
}

run "rejects_unknown_module_provider" {
  command = plan
  variables { module = "azure-blob" }
  expect_failures = [var.module]
}
