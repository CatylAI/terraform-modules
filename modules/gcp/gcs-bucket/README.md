# gcp/gcs-bucket

A Cloud Storage bucket with every protection on by default. It follows
[the module standard](../../../docs/spec/module-standard.md).

```hcl
module "uploads" {
  source = "git::https://github.com/CatylAI/terraform-modules.git//modules/gcp/gcs-bucket?ref=gcp-gcs-bucket-v0.1.0"

  context    = local.context # tenant, environment, component, repo from the root
  name       = "uploads"     # bucket: <tenant>-<environment>-<component>-uploads
  project_id = var.project_id
  location   = var.bucket_location
}
```

## Defaults, and how to override them

| Setting | Default | Override (in the root's tfvars) |
|---|---|---|
| Uniform bucket-level access | on | none (invariant) |
| Public access prevention | `enforced` | `public_access = { enabled = true, justification = "..." }` (20+ characters; also adds the label `public-access=true`) |
| Versioning | on; noncurrent versions deleted after 30 days | `versioning = { enabled = false }`, or `noncurrent_retention_days = 0` to keep them forever |
| Incomplete multipart uploads | aborted after 1 day | `multipart_upload_cleanup = { enabled = false }` or `{ age_days = 7 }` |
| Soft delete | 7 days | `soft_delete = { retention_days = 0 \| 7..90 }` |
| Deletion | `deletion_policy = "PREVENT"`, no `force_destroy` | `deletion_protection = { enabled = false, force_destroy = true }` for scratch environments |
| Encryption | Google-managed | `encryption = { kms_key_name = "projects/.../cryptoKeys/..." }` |
| IAM | none | `iam = { <name> = { role, members } }`, additive. Primitive roles, `allUsers` and `allAuthenticatedUsers` are rejected |
| Access logs | off (use Cloud Audit Logs) | `access_logging = { log_bucket = "<bucket>" }` |
| CORS | none | `cors = { <name> = { origins, methods } }`; `*` origins are rejected |
| Notifications | none | `notifications = { <name> = { topic } }`; grants the GCS service agent `pubsub.publisher` on the topic |

Each group is an object with optional attributes. Set one attribute and the rest keep their
defaults. The two cost guards are ordinary lifecycle rules under the reserved keys
`managed-noncurrent-expiry` and `managed-abort-multipart`, so they show in every plan. Your own
`lifecycle_rules` are added alongside them.

## Cost shape

You pay for stored bytes by storage class, operations, and egress. Nothing is reserved. Cost
grows with data and traffic, not with time: noncurrent versions, soft-deleted objects and
abandoned uploads all expire by default (module-standard MS-14). To reach growth scale, change
inputs; the module call stays the same:

- `location` multi-region or dual-region for availability
- CMEK
- `autoclass` or `lifecycle_rules` to tier cold data

## Adopting an existing bucket

Set `name_override` to the existing name, add a `moved` block (from a raw resource) or an
`import` block, and require a plan that shows no changes (ADR-0013).

```hcl
moved {
  from = google_storage_bucket.uploads
  to   = module.uploads.google_storage_bucket.this[0]
}
```

## Architecture Framework

| Pillar | Default | Trade-off |
|---|---|---|
| Security | Uniform access, public access prevention enforced, no primitive roles, no public principals outside `public_access`, optional CMEK | CMEK adds a key dependency and a KMS cost; it is opt-in |
| Reliability | Versioning, soft delete, `deletion_policy = "PREVENT"` | 30-day noncurrent expiry bounds how far back a restore can reach; raise it for longer recovery |
| Cost optimization | Labels on every bucket; noncurrent and multipart expiry on by default; lifecycle rules and Autoclass available | Autoclass is off, because its management fee only pays off on mixed access patterns |
| Operational excellence | Name and labels derived from context; one input shape across modules | None |
| Performance | Location is a required input, so data sits where the workload is | None |
| Sustainability | Lifecycle expiry keeps no data longer than its rule allows | None |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.14, < 2.0 |
| google | >= 8.3, < 9.0 |

## Providers

| Name | Version |
| ---- | ------- |
| google | >= 8.3, < 9.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| context | ../../_internal/context | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [google_pubsub_topic_iam_member.gcs_publisher](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic_iam_member) | resource |
| [google_storage_bucket.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_notification.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_notification) | resource |
| [google_storage_project_service_account.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| context | Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3). | ```object({ tenant = string environment = string component = string repo = string labels = optional(map(string), {}) allowed_environments = optional(list(string)) name_prefix = optional(string) })``` | n/a | yes |
| location | Bucket location in upper case, e.g. US-EAST1, US or a dual-region. Required: it differs per deployment and cannot be changed later. | `string` | n/a | yes |
| name | Logical name of this bucket, unique within the component. Kebab-case. The bucket is named <prefix>-<name>, where prefix is context.name_prefix or <tenant>-<environment>-<component>. | `string` | n/a | yes |
| project_id | Project that owns the bucket. | `string` | n/a | yes |
| access_logging | GCS usage and storage logs delivered to another bucket. Off by default: Cloud Audit Logs (Data Access) are the recommended access record. Turn this on when you need GCS usage logs specifically. | ```object({ log_bucket = optional(string) log_object_prefix = optional(string) })``` | `{}` | no |
| autoclass | Autoclass moves objects between storage classes by access pattern. | ```object({ enabled = optional(bool, false) terminal_storage_class = optional(string) })``` | `{}` | no |
| cors | CORS rules keyed by a stable rule name. | ```map(object({ origins = list(string) methods = list(string) response_headers = optional(list(string), []) max_age_seconds = optional(number, 3600) }))``` | `{}` | no |
| deletion_protection | When enabled, Terraform refuses to destroy the bucket (deletion_policy PREVENT). force_destroy deletes objects on destroy and is only allowed with protection off. | ```object({ enabled = optional(bool, true) force_destroy = optional(bool, false) })``` | `{}` | no |
| enabled | Set false to create nothing. Every output is then null. | `bool` | `true` | no |
| encryption | Customer-managed encryption. Null kms_key_name uses Google-managed keys. | ```object({ kms_key_name = optional(string) })``` | `{}` | no |
| iam | Additive IAM bindings keyed by a stable binding name. Primitive roles and public principals are rejected; public read goes through public_access. | ```map(object({ role = string members = set(string) }))``` | `{}` | no |
| lifecycle_rules | Object lifecycle rules keyed by a stable rule name, added to the module's own cost guards (versioning, multipart_upload_cleanup). Each rule is one action and one condition; see the GCS lifecycle documentation for condition semantics. | ```map(object({ action = object({ type = string storage_class = optional(string) }) condition = object({ age = optional(number) created_before = optional(string) with_state = optional(string) matches_prefix = optional(list(string)) matches_suffix = optional(list(string)) matches_storage_class = optional(list(string)) num_newer_versions = optional(number) days_since_noncurrent_time = optional(number) noncurrent_time_before = optional(string) days_since_custom_time = optional(number) }) }))``` | `{}` | no |
| multipart_upload_cleanup | Aborts incomplete multipart uploads after age_days, so abandoned parts stop being billed (MS-14.3). | ```object({ enabled = optional(bool, true) age_days = optional(number, 1) })``` | `{}` | no |
| name_override | Verbatim bucket name, only for adopting a bucket that predates the naming convention (ADR-0013). Leave null for new buckets. | `string` | `null` | no |
| notifications | Pub/Sub notifications keyed by a stable name. The bucket's service agent is granted roles/pubsub.publisher on each topic unless grant_publisher is false. | ```map(object({ topic = string event_types = optional(set(string), ["OBJECT_FINALIZE"]) payload_format = optional(string, "JSON_API_V1") object_name_prefix = optional(string) custom_attributes = optional(map(string), {}) grant_publisher = optional(bool, true) }))``` | `{}` | no |
| public_access | Public read of objects. Off by default; turning it on requires a justification of at least 20 characters (MS-5.3). The org policy storage.publicAccessPrevention must also allow it. | ```object({ enabled = optional(bool, false) justification = optional(string, "") })``` | `{}` | no |
| retention_policy | Bucket retention policy: objects cannot be deleted or overwritten before retention_period_seconds. A locked policy can never be reduced or removed. | ```object({ enabled = optional(bool, false) retention_period_seconds = optional(number, 0) locked = optional(bool, false) })``` | `{}` | no |
| soft_delete | Soft delete keeps deleted objects restorable for retention_days. 0 turns it off; otherwise 7 to 90 days. | ```object({ retention_days = optional(number, 7) })``` | `{}` | no |
| storage_class | Default storage class for new objects. | `string` | `"STANDARD"` | no |
| versioning | Object versioning. Keeps prior generations so an overwrite or delete is recoverable. Noncurrent generations are deleted after noncurrent_retention_days (0 keeps them forever), so storage cost stays bounded (MS-14.3). | ```object({ enabled = optional(bool, true) noncurrent_retention_days = optional(number, 30) })``` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| name | Bucket name. Null when the module is disabled. |
| notification_ids | Notification ids keyed like var.notifications. |
| self_link | API self link of the bucket. Null when the module is disabled. |
| url | gs:// URL of the bucket. Null when the module is disabled. |
<!-- END_TF_DOCS -->
