variable "context" {
  description = "Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3)."
  type = object({
    tenant               = string
    environment          = string
    component            = string
    repo                 = string
    labels               = optional(map(string), {})
    allowed_environments = optional(list(string))
    name_prefix          = optional(string)
  })
  nullable = false
}

variable "name" {
  description = "Logical name of this bucket, unique within the component. Kebab-case. The bucket is named <prefix>-<name>, where prefix is context.name_prefix or <tenant>-<environment>-<component>."
  type        = string
}

variable "enabled" {
  description = "Set false to create nothing. Every output is then null."
  type        = bool
  default     = true
  nullable    = false
}

variable "name_override" {
  description = "Verbatim bucket name, only for adopting a bucket that predates the naming convention (ADR-0013). Leave null for new buckets."
  type        = string
  default     = null
}

variable "project_id" {
  description = "Project that owns the bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a GCP project id: 6-30 characters, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "location" {
  description = "Bucket location in upper case, e.g. US-EAST1, US or a dual-region. Required: it differs per deployment and cannot be changed later."
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9-]+$", var.location))
    error_message = "location must be upper case (e.g. US-EAST1). The API returns it upper case, so a lower-case value diffs on every plan."
  }
}

variable "storage_class" {
  description = "Default storage class for new objects."
  type        = string
  default     = "STANDARD"
  nullable    = false

  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "storage_class must be one of: STANDARD, NEARLINE, COLDLINE, ARCHIVE."
  }
}

variable "versioning" {
  description = "Object versioning. Keeps prior generations so an overwrite or delete is recoverable. Noncurrent generations are deleted after noncurrent_retention_days (0 keeps them forever), so storage cost stays bounded (MS-14.3)."
  type = object({
    enabled                   = optional(bool, true)
    noncurrent_retention_days = optional(number, 30)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.versioning.noncurrent_retention_days >= 0
    error_message = "versioning.noncurrent_retention_days must be 0 (keep forever) or a positive number of days."
  }
}

variable "multipart_upload_cleanup" {
  description = "Aborts incomplete multipart uploads after age_days, so abandoned parts stop being billed (MS-14.3)."
  type = object({
    enabled  = optional(bool, true)
    age_days = optional(number, 1)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.multipart_upload_cleanup.age_days >= 1
    error_message = "multipart_upload_cleanup.age_days must be at least 1."
  }
}

variable "soft_delete" {
  description = "Soft delete keeps deleted objects restorable for retention_days. 0 turns it off; otherwise 7 to 90 days."
  type = object({
    retention_days = optional(number, 7)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.soft_delete.retention_days == 0 || (var.soft_delete.retention_days >= 7 && var.soft_delete.retention_days <= 90)
    error_message = "soft_delete.retention_days must be 0 (off) or between 7 and 90."
  }
}

variable "encryption" {
  description = "Customer-managed encryption. Null kms_key_name uses Google-managed keys."
  type = object({
    kms_key_name = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.encryption.kms_key_name == null || can(regex("^projects/[^/]+/locations/[^/]+/keyRings/[^/]+/cryptoKeys/[^/]+$", var.encryption.kms_key_name))
    error_message = "encryption.kms_key_name must be a full key name: projects/<p>/locations/<l>/keyRings/<r>/cryptoKeys/<k>."
  }
}

variable "deletion_protection" {
  description = "When enabled, Terraform refuses to destroy the bucket (deletion_policy PREVENT). force_destroy deletes objects on destroy and is only allowed with protection off."
  type = object({
    enabled       = optional(bool, true)
    force_destroy = optional(bool, false)
  })
  default  = {}
  nullable = false

  validation {
    condition     = !(var.deletion_protection.enabled && var.deletion_protection.force_destroy)
    error_message = "deletion_protection.force_destroy requires deletion_protection.enabled = false."
  }
}

variable "access_logging" {
  description = "GCS usage and storage logs delivered to another bucket. Off by default: Cloud Audit Logs (Data Access) are the recommended access record. Turn this on when you need GCS usage logs specifically."
  type = object({
    log_bucket        = optional(string)
    log_object_prefix = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.access_logging.log_bucket == null || can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", coalesce(var.access_logging.log_bucket, "xxx")))
    error_message = "access_logging.log_bucket must be a bucket name (not a gs:// URL)."
  }
}

variable "lifecycle_rules" {
  description = "Object lifecycle rules keyed by a stable rule name, added to the module's own cost guards (versioning, multipart_upload_cleanup). Each rule is one action and one condition; see the GCS lifecycle documentation for condition semantics."
  type = map(object({
    action = object({
      type          = string
      storage_class = optional(string)
    })
    condition = object({
      age                        = optional(number)
      created_before             = optional(string)
      with_state                 = optional(string)
      matches_prefix             = optional(list(string))
      matches_suffix             = optional(list(string))
      matches_storage_class      = optional(list(string))
      num_newer_versions         = optional(number)
      days_since_noncurrent_time = optional(number)
      noncurrent_time_before     = optional(string)
      days_since_custom_time     = optional(number)
    })
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for k in keys(var.lifecycle_rules) : !startswith(k, "managed-")])
    error_message = "lifecycle_rules keys must not start with 'managed-'; that prefix is reserved for the module's own cost guards."
  }

  validation {
    condition     = alltrue([for r in values(var.lifecycle_rules) : contains(["Delete", "SetStorageClass", "AbortIncompleteMultipartUpload"], r.action.type)])
    error_message = "lifecycle_rules action.type must be one of: Delete, SetStorageClass, AbortIncompleteMultipartUpload."
  }

  validation {
    condition     = alltrue([for r in values(var.lifecycle_rules) : (r.action.type == "SetStorageClass") == (r.action.storage_class != null)])
    error_message = "lifecycle_rules action.storage_class is required for SetStorageClass and not allowed for other actions."
  }
}

variable "retention_policy" {
  description = "Bucket retention policy: objects cannot be deleted or overwritten before retention_period_seconds. A locked policy can never be reduced or removed."
  type = object({
    enabled                  = optional(bool, false)
    retention_period_seconds = optional(number, 0)
    locked                   = optional(bool, false)
  })
  default  = {}
  nullable = false

  validation {
    condition     = !var.retention_policy.enabled || var.retention_policy.retention_period_seconds > 0
    error_message = "retention_policy.retention_period_seconds must be greater than 0 when the policy is enabled."
  }
}

variable "autoclass" {
  description = "Autoclass moves objects between storage classes by access pattern."
  type = object({
    enabled                = optional(bool, false)
    terminal_storage_class = optional(string)
  })
  default  = {}
  nullable = false
}

variable "cors" {
  description = "CORS rules keyed by a stable rule name."
  type = map(object({
    origins          = list(string)
    methods          = list(string)
    response_headers = optional(list(string), [])
    max_age_seconds  = optional(number, 3600)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for c in values(var.cors) : !contains(c.origins, "*")])
    error_message = "cors origins must be explicit; '*' is not allowed."
  }
}

variable "iam" {
  description = "Additive IAM bindings keyed by a stable binding name. Primitive roles and public principals are rejected; public read goes through public_access."
  type = map(object({
    role    = string
    members = set(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for b in values(var.iam) : !contains(["roles/owner", "roles/editor", "roles/viewer"], b.role)])
    error_message = "iam must not grant primitive roles (roles/owner, roles/editor, roles/viewer) (module-standard MS-6.3)."
  }

  validation {
    condition     = alltrue([for b in values(var.iam) : length(setintersection(b.members, ["allUsers", "allAuthenticatedUsers"])) == 0])
    error_message = "iam must not grant allUsers or allAuthenticatedUsers; use public_access with a justification (MS-6.4)."
  }
}

variable "public_access" {
  description = "Public read of objects. Off by default; turning it on requires a justification of at least 20 characters (MS-5.3). The org policy storage.publicAccessPrevention must also allow it."
  type = object({
    enabled       = optional(bool, false)
    justification = optional(string, "")
  })
  default  = {}
  nullable = false

  validation {
    condition     = !var.public_access.enabled || length(trimspace(var.public_access.justification)) >= 20
    error_message = "public_access.enabled requires a justification of at least 20 characters."
  }
}

variable "notifications" {
  description = "Pub/Sub notifications keyed by a stable name. The bucket's service agent is granted roles/pubsub.publisher on each topic unless grant_publisher is false."
  type = map(object({
    topic              = string
    event_types        = optional(set(string), ["OBJECT_FINALIZE"])
    payload_format     = optional(string, "JSON_API_V1")
    object_name_prefix = optional(string)
    custom_attributes  = optional(map(string), {})
    grant_publisher    = optional(bool, true)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for n in values(var.notifications) : can(regex("^projects/[^/]+/topics/[^/]+$", n.topic))])
    error_message = "notifications topic must be a full topic id: projects/<p>/topics/<t>."
  }

  validation {
    condition     = alltrue([for n in values(var.notifications) : length(setsubtract(n.event_types, ["OBJECT_FINALIZE", "OBJECT_METADATA_UPDATE", "OBJECT_DELETE", "OBJECT_ARCHIVE"])) == 0])
    error_message = "notifications event_types must be among: OBJECT_FINALIZE, OBJECT_METADATA_UPDATE, OBJECT_DELETE, OBJECT_ARCHIVE."
  }
}
