# The provider validates IAM member syntax at plan time, so the service-agent data source needs a
# realistic value rather than the mock's random string.
mock_provider "google" {
  mock_data "google_storage_project_service_account" {
    defaults = {
      email_address = "service-123456789012@gs-project-accounts.iam.gserviceaccount.com"
      member        = "serviceAccount:service-123456789012@gs-project-accounts.iam.gserviceaccount.com"
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
  name       = "uploads"
  project_id = "acme-uat"
  location   = "US-EAST1"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = google_storage_bucket.this[0].name == "acme-uat-orders-uploads"
    error_message = "bucket name must follow <tenant>-<environment>-<component>-<name>."
  }
  assert {
    condition     = google_storage_bucket.this[0].uniform_bucket_level_access == true
    error_message = "uniform bucket-level access must be on."
  }
  assert {
    condition     = google_storage_bucket.this[0].public_access_prevention == "enforced"
    error_message = "public access prevention must be enforced by default."
  }
  assert {
    condition     = google_storage_bucket.this[0].versioning[0].enabled == true
    error_message = "versioning must be on by default."
  }
  assert {
    condition     = google_storage_bucket.this[0].soft_delete_policy[0].retention_duration_seconds == 604800
    error_message = "soft delete must keep objects 7 days by default."
  }
  assert {
    condition     = google_storage_bucket.this[0].deletion_policy == "PREVENT" && google_storage_bucket.this[0].force_destroy == false
    error_message = "the bucket must be deletion-protected and never force-destroyed by default."
  }
  assert {
    condition     = google_storage_bucket.this[0].storage_class == "STANDARD"
    error_message = "storage class must default to STANDARD."
  }
  assert {
    condition     = length(google_storage_bucket.this[0].encryption) == 0 && length(google_storage_bucket.this[0].retention_policy) == 0 && length(google_storage_bucket.this[0].cors) == 0
    error_message = "optional blocks must be absent by default."
  }
  assert {
    condition     = length(google_storage_bucket.this[0].logging) == 0
    error_message = "access logging must be off by default."
  }
  assert {
    condition     = length(google_storage_bucket.this[0].lifecycle_rule) == 2
    error_message = "the two cost guards must be the only lifecycle rules by default."
  }
  assert {
    condition = anytrue([for r in google_storage_bucket.this[0].lifecycle_rule :
      one(r.action).type == "Delete" && one(r.condition).days_since_noncurrent_time == 30 && one(r.condition).with_state == "ARCHIVED"
    ])
    error_message = "noncurrent versions must expire after 30 days by default."
  }
  assert {
    condition = anytrue([for r in google_storage_bucket.this[0].lifecycle_rule :
      one(r.action).type == "AbortIncompleteMultipartUpload" && one(r.condition).age == 1
    ])
    error_message = "incomplete multipart uploads must be aborted after 1 day by default."
  }
  assert {
    condition     = length(google_storage_bucket_iam_member.this) == 0 && length(google_storage_notification.this) == 0 && length(google_pubsub_topic_iam_member.gcs_publisher) == 0
    error_message = "no IAM or notifications by default."
  }
  assert {
    condition     = google_storage_bucket.this[0].labels["managed-by"] == "terraform" && google_storage_bucket.this[0].labels["environment"] == "uat" && google_storage_bucket.this[0].labels["module"] == "gcp-gcs-bucket" && !contains(keys(google_storage_bucket.this[0].labels), "public-access")
    error_message = "reserved labels must be applied, and public-access must be absent."
  }
}

run "disabled_creates_nothing" {
  command = plan
  variables {
    enabled       = false
    iam           = { readers = { role = "roles/storage.objectViewer", members = ["group:readers@example.com"] } }
    notifications = { uploads = { topic = "projects/acme-uat/topics/uploads" } }
  }

  assert {
    condition     = length(google_storage_bucket.this) == 0 && length(google_storage_bucket_iam_member.this) == 0 && length(google_storage_notification.this) == 0 && length(google_pubsub_topic_iam_member.gcs_publisher) == 0
    error_message = "enabled = false must create nothing."
  }
  assert {
    condition     = output.name == null && output.url == null && output.self_link == null && output.notification_ids == {}
    error_message = "outputs must be null (or empty) when disabled."
  }
}

run "adopts_existing_name" {
  command = plan
  variables { name_override = "orders-uploads-legacy" }

  assert {
    condition     = google_storage_bucket.this[0].name == "orders-uploads-legacy" && google_storage_bucket.this[0].labels["component"] == "orders"
    error_message = "name_override must be used verbatim, with labels still applied."
  }
}

run "overrides_keep_other_defaults" {
  command = plan
  variables {
    versioning          = { enabled = false }
    soft_delete         = { retention_days = 0 }
    deletion_protection = { enabled = false, force_destroy = true }
  }

  assert {
    condition     = google_storage_bucket.this[0].versioning[0].enabled == false && google_storage_bucket.this[0].soft_delete_policy[0].retention_duration_seconds == 0
    error_message = "explicit overrides must apply."
  }
  assert {
    condition     = length(google_storage_bucket.this[0].lifecycle_rule) == 1
    error_message = "with versioning off, the noncurrent-expiry guard must go and the multipart guard stay."
  }
  assert {
    condition     = google_storage_bucket.this[0].deletion_policy == "DELETE" && google_storage_bucket.this[0].force_destroy == true
    error_message = "deletion protection must be switchable off for scratch environments."
  }
  assert {
    condition     = google_storage_bucket.this[0].public_access_prevention == "enforced" && google_storage_bucket.this[0].uniform_bucket_level_access == true
    error_message = "unrelated secure defaults must survive other overrides."
  }
}

run "complete_configuration" {
  command = plan
  variables {
    encryption       = { kms_key_name = "projects/acme-uat/locations/us-east1/keyRings/data/cryptoKeys/gcs" }
    retention_policy = { enabled = true, retention_period_seconds = 86400 }
    autoclass        = { enabled = true, terminal_storage_class = "ARCHIVE" }
    access_logging   = { log_bucket = "acme-uat-logs", log_object_prefix = "uploads/" }
    lifecycle_rules = {
      expire-noncurrent = {
        action    = { type = "Delete" }
        condition = { days_since_noncurrent_time = 30, with_state = "ARCHIVED" }
      }
      cool-old = {
        action    = { type = "SetStorageClass", storage_class = "NEARLINE" }
        condition = { age = 90 }
      }
    }
    cors = {
      web = { origins = ["https://www.example.com"], methods = ["GET", "HEAD"] }
    }
    iam = {
      readers = { role = "roles/storage.objectViewer", members = ["group:readers@example.com", "serviceAccount:api@acme-uat.iam.gserviceaccount.com"] }
    }
    notifications = {
      uploads = { topic = "projects/acme-uat/topics/uploads", object_name_prefix = "incoming/" }
    }
  }

  assert {
    condition     = google_storage_bucket.this[0].encryption[0].default_kms_key_name == "projects/acme-uat/locations/us-east1/keyRings/data/cryptoKeys/gcs"
    error_message = "CMEK must be set when kms_key_name is given."
  }
  assert {
    condition     = length(google_storage_bucket.this[0].lifecycle_rule) == 4 && length(google_storage_bucket.this[0].cors) == 1
    error_message = "caller lifecycle rules are added to the two cost guards; one cors block per rule."
  }
  assert {
    condition     = google_storage_bucket.this[0].logging[0].log_bucket == "acme-uat-logs" && google_storage_bucket.this[0].logging[0].log_object_prefix == "uploads/"
    error_message = "access logging must be delivered to the given bucket."
  }
  assert {
    condition     = google_storage_bucket.this[0].retention_policy[0].retention_period == "86400" && google_storage_bucket.this[0].retention_policy[0].is_locked == false
    error_message = "retention policy must be set, unlocked by default."
  }
  assert {
    condition     = length(google_storage_bucket_iam_member.this) == 2 && contains(keys(google_storage_bucket_iam_member.this), "readers/group:readers@example.com")
    error_message = "one IAM member per binding member, keyed <binding>/<member>."
  }
  assert {
    condition     = length(google_storage_notification.this) == 1 && length(google_pubsub_topic_iam_member.gcs_publisher) == 1
    error_message = "a notification must come with the publisher grant on its topic."
  }
}

run "public_access_with_justification" {
  command = plan
  variables { public_access = { enabled = true, justification = "Static storefront assets are served directly to browsers." } }

  assert {
    condition     = google_storage_bucket.this[0].public_access_prevention == "inherited" && google_storage_bucket.this[0].labels["public-access"] == "true"
    error_message = "public access must lift prevention and mark the bucket with a public-access label."
  }
  assert {
    condition     = google_storage_bucket_iam_member.this["public-access/allUsers"].member == "allUsers" && google_storage_bucket_iam_member.this["public-access/allUsers"].role == "roles/storage.objectViewer"
    error_message = "public access must grant allUsers object read only."
  }
}

run "rejects_public_access_without_justification" {
  command = plan
  variables { public_access = { enabled = true, justification = "because" } }
  expect_failures = [var.public_access]
}

run "rejects_primitive_role" {
  command = plan
  variables { iam = { admins = { role = "roles/editor", members = ["group:admins@example.com"] } } }
  expect_failures = [var.iam]
}

run "rejects_public_principal_in_iam" {
  command = plan
  variables { iam = { everyone = { role = "roles/storage.objectViewer", members = ["allUsers"] } } }
  expect_failures = [var.iam]
}

run "rejects_force_destroy_while_protected" {
  command = plan
  variables { deletion_protection = { force_destroy = true } }
  expect_failures = [var.deletion_protection]
}

run "rejects_lowercase_location" {
  command = plan
  variables { location = "us-east1" }
  expect_failures = [var.location]
}

run "rejects_invalid_project_id" {
  command = plan
  variables { project_id = "Bad_Project" }
  expect_failures = [var.project_id]
}

run "rejects_unknown_storage_class" {
  command = plan
  variables { storage_class = "MULTI_REGIONAL" }
  expect_failures = [var.storage_class]
}

run "rejects_soft_delete_out_of_range" {
  command = plan
  variables { soft_delete = { retention_days = 3 } }
  expect_failures = [var.soft_delete]
}

run "rejects_short_kms_key_name" {
  command = plan
  variables { encryption = { kms_key_name = "gcs-key" } }
  expect_failures = [var.encryption]
}

run "cost_guards_can_be_switched_off" {
  command = plan
  variables {
    versioning               = { noncurrent_retention_days = 0 }
    multipart_upload_cleanup = { enabled = false }
  }

  assert {
    condition     = google_storage_bucket.this[0].versioning[0].enabled == true && length(google_storage_bucket.this[0].lifecycle_rule) == 0
    error_message = "noncurrent_retention_days = 0 keeps versions forever; disabling cleanup removes its rule."
  }
}

run "rejects_reserved_lifecycle_key" {
  command = plan
  variables {
    lifecycle_rules = { managed-noncurrent-expiry = { action = { type = "Delete" }, condition = { age = 1 } } }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_unknown_lifecycle_action" {
  command = plan
  variables {
    lifecycle_rules = { bad = { action = { type = "Archive" }, condition = { age = 1 } } }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_storage_class_on_delete_action" {
  command = plan
  variables {
    lifecycle_rules = { bad = { action = { type = "Delete", storage_class = "NEARLINE" }, condition = { age = 1 } } }
  }
  expect_failures = [var.lifecycle_rules]
}

run "rejects_unlimited_retention_period" {
  command = plan
  variables { retention_policy = { enabled = true } }
  expect_failures = [var.retention_policy]
}

run "rejects_wildcard_cors_origin" {
  command = plan
  variables { cors = { any = { origins = ["*"], methods = ["GET"] } } }
  expect_failures = [var.cors]
}

run "rejects_log_bucket_url" {
  command = plan
  variables { access_logging = { log_bucket = "gs://acme-uat-logs" } }
  expect_failures = [var.access_logging]
}

run "rejects_short_topic_id" {
  command = plan
  variables { notifications = { n = { topic = "uploads" } } }
  expect_failures = [var.notifications]
}

run "rejects_unknown_event_type" {
  command = plan
  variables { notifications = { n = { topic = "projects/acme-uat/topics/uploads", event_types = ["OBJECT_CREATE"] } } }
  expect_failures = [var.notifications]
}

run "rejects_name_too_long_for_gcs" {
  command = plan
  variables {
    context = { tenant = "initech", environment = "staging", component = "a-very-long-component-name-x", repo = "r" }
    name    = "an-equally-long-instance-name"
  }
  expect_failures = [google_storage_bucket.this[0]]
}
