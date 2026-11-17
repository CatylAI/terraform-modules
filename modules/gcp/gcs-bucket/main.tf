module "context" {
  source = "../../_internal/context"

  context       = var.context
  name          = var.name
  module        = "gcp-gcs-bucket"
  name_override = var.name_override
}

locals {
  labels = merge(module.context.labels, var.public_access.enabled ? { "public-access" = "true" } : {})

  iam_members = var.enabled ? merge(
    { for pair in flatten([
      for key, binding in var.iam : [
        for member in binding.members : { key = "${key}/${member}", role = binding.role, member = member }
      ]
    ]) : pair.key => { role = pair.role, member = pair.member } },
    var.public_access.enabled ? { "public-access/allUsers" = { role = "roles/storage.objectViewer", member = "allUsers" } } : {}
  ) : {}

  # Cost guards (MS-14.3) are ordinary lifecycle rules under reserved keys, so they show in the
  # plan like any other rule and a caller can switch them off explicitly.
  managed_lifecycle_rules = merge(
    var.versioning.enabled && var.versioning.noncurrent_retention_days > 0 ? {
      managed-noncurrent-expiry = {
        action    = { type = "Delete", storage_class = null }
        condition = { age = null, created_before = null, with_state = "ARCHIVED", matches_prefix = null, matches_suffix = null, matches_storage_class = null, num_newer_versions = null, days_since_noncurrent_time = var.versioning.noncurrent_retention_days, noncurrent_time_before = null, days_since_custom_time = null }
      }
    } : {},
    var.multipart_upload_cleanup.enabled ? {
      managed-abort-multipart = {
        action    = { type = "AbortIncompleteMultipartUpload", storage_class = null }
        condition = { age = var.multipart_upload_cleanup.age_days, created_before = null, with_state = null, matches_prefix = null, matches_suffix = null, matches_storage_class = null, num_newer_versions = null, days_since_noncurrent_time = null, noncurrent_time_before = null, days_since_custom_time = null }
      }
    } : {}
  )
  lifecycle_rules = merge(local.managed_lifecycle_rules, var.lifecycle_rules)

  notifications    = var.enabled ? var.notifications : {}
  publisher_topics = toset([for n in values(local.notifications) : n.topic if n.grant_publisher])
}

resource "google_storage_bucket" "this" {
  count = var.enabled ? 1 : 0

  project       = var.project_id
  name          = module.context.name
  location      = var.location
  storage_class = var.storage_class
  labels        = local.labels

  uniform_bucket_level_access = true
  public_access_prevention    = var.public_access.enabled ? "inherited" : "enforced"
  deletion_policy             = var.deletion_protection.enabled ? "PREVENT" : "DELETE"
  force_destroy               = var.deletion_protection.force_destroy

  versioning {
    enabled = var.versioning.enabled
  }

  soft_delete_policy {
    retention_duration_seconds = var.soft_delete.retention_days * 86400
  }

  dynamic "encryption" {
    for_each = var.encryption.kms_key_name == null ? [] : [var.encryption]
    content {
      default_kms_key_name = encryption.value.kms_key_name
    }
  }

  dynamic "logging" {
    for_each = var.access_logging.log_bucket == null ? [] : [var.access_logging]
    content {
      log_bucket        = logging.value.log_bucket
      log_object_prefix = logging.value.log_object_prefix
    }
  }

  dynamic "retention_policy" {
    for_each = var.retention_policy.enabled ? [var.retention_policy] : []
    content {
      retention_period = tostring(retention_policy.value.retention_period_seconds) # string in google 8.x
      is_locked        = retention_policy.value.locked
    }
  }

  dynamic "autoclass" {
    for_each = var.autoclass.enabled ? [var.autoclass] : []
    content {
      enabled                = true
      terminal_storage_class = autoclass.value.terminal_storage_class
    }
  }

  dynamic "lifecycle_rule" {
    for_each = local.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = lifecycle_rule.value.action.storage_class
      }
      condition {
        age                        = lifecycle_rule.value.condition.age
        created_before             = lifecycle_rule.value.condition.created_before
        with_state                 = lifecycle_rule.value.condition.with_state
        matches_prefix             = lifecycle_rule.value.condition.matches_prefix
        matches_suffix             = lifecycle_rule.value.condition.matches_suffix
        matches_storage_class      = lifecycle_rule.value.condition.matches_storage_class
        num_newer_versions         = lifecycle_rule.value.condition.num_newer_versions
        days_since_noncurrent_time = lifecycle_rule.value.condition.days_since_noncurrent_time
        noncurrent_time_before     = lifecycle_rule.value.condition.noncurrent_time_before
        days_since_custom_time     = lifecycle_rule.value.condition.days_since_custom_time
      }
    }
  }

  dynamic "cors" {
    for_each = var.cors
    content {
      origin          = cors.value.origins
      method          = cors.value.methods
      response_header = cors.value.response_headers
      max_age_seconds = cors.value.max_age_seconds
    }
  }

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", module.context.name)) && !strcontains(module.context.name, "google")
      error_message = "The bucket name must be 3-63 characters of lowercase letters, digits, '-', '_' and '.', and must not contain 'google'. Shorten name or component."
    }
  }
}

resource "google_storage_bucket_iam_member" "this" {
  for_each = local.iam_members

  bucket = google_storage_bucket.this[0].name
  role   = each.value.role
  member = each.value.member
}

data "google_storage_project_service_account" "this" {
  count   = length(local.publisher_topics) > 0 ? 1 : 0
  project = var.project_id
}

resource "google_pubsub_topic_iam_member" "gcs_publisher" {
  for_each = local.publisher_topics

  topic  = each.value
  role   = "roles/pubsub.publisher"
  member = data.google_storage_project_service_account.this[0].member
}

resource "google_storage_notification" "this" {
  for_each = local.notifications

  bucket             = google_storage_bucket.this[0].name
  topic              = each.value.topic
  event_types        = each.value.event_types
  payload_format     = each.value.payload_format
  object_name_prefix = each.value.object_name_prefix
  custom_attributes  = each.value.custom_attributes

  depends_on = [google_pubsub_topic_iam_member.gcs_publisher]
}
