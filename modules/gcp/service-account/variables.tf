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
  description = "Logical name of this service account, unique within the component. Kebab-case. The account id is <prefix>-<name>, where prefix is context.name_prefix or <tenant>-<environment>-<component>; it must come to 6-30 characters."
  type        = string
}

variable "enabled" {
  description = "Set false to create nothing. Every output is then null."
  type        = bool
  default     = true
  nullable    = false
}

variable "name_override" {
  description = "Verbatim account id, only for adopting a service account that predates the naming convention (ADR-0013). Leave null for new accounts. It must still be 6-30 characters."
  type        = string
  default     = null
}

variable "project_id" {
  description = "Project that owns the service account and receives its project role bindings."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a GCP project id: 6-30 characters, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "display_name" {
  description = "Human-readable name shown in the console. Null leaves it unset. At most 100 characters."
  type        = string
  default     = null

  validation {
    condition     = var.display_name == null || length(coalesce(var.display_name, "x")) <= 100
    error_message = "display_name must be at most 100 characters."
  }
}

variable "description" {
  description = "What the account is for. Null leaves it unset. At most 256 characters."
  type        = string
  default     = null

  validation {
    condition     = var.description == null || length(coalesce(var.description, "x")) <= 256
    error_message = "description must be at most 256 characters."
  }
}

variable "project_roles" {
  description = "Project roles granted to this service account in project_id, keyed by a stable binding name. Each binding is additive (one IAM member), so the module never removes a grant it did not create. Basic roles are rejected."
  type = map(object({
    role = string
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for b in values(var.project_roles) : can(regex("^(roles/[A-Za-z0-9_.]+|projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/roles/[A-Za-z0-9_.]+|organizations/[0-9]+/roles/[A-Za-z0-9_.]+)$", b.role))])
    error_message = "project_roles role must be a predefined role (roles/<id>) or a custom role (projects/<p>/roles/<id> or organizations/<o>/roles/<id>)."
  }

  validation {
    condition     = alltrue([for b in values(var.project_roles) : !contains(["roles/owner", "roles/editor", "roles/viewer"], b.role)])
    error_message = "project_roles must not grant basic roles (roles/owner, roles/editor, roles/viewer) (module-standard MS-6.3)."
  }
}

variable "impersonation" {
  description = "Principals allowed to act as this service account, keyed by a stable binding name. role must be one of roles/iam.serviceAccountTokenCreator (mint access and ID tokens), roles/iam.serviceAccountOpenIdTokenCreator (ID tokens only), roles/iam.serviceAccountUser (attach the account to a workload) or roles/iam.workloadIdentityUser (Workload Identity Federation or GKE sign-in). Nothing is granted by default, so token creation exists only through an explicit entry. Members are a map keyed by a stable member name (e.g. { ci = \"principalSet://...\" }), so a principal created in the same apply can be granted; each is an additive binding. Public principals are rejected."
  type = map(object({
    role    = string
    members = map(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for b in values(var.impersonation) : !contains(["roles/owner", "roles/editor", "roles/viewer"], b.role)])
    error_message = "impersonation must not grant basic roles (roles/owner, roles/editor, roles/viewer) (module-standard MS-6.3)."
  }

  validation {
    condition     = alltrue([for b in values(var.impersonation) : contains(["roles/iam.serviceAccountTokenCreator", "roles/iam.serviceAccountOpenIdTokenCreator", "roles/iam.serviceAccountUser", "roles/iam.workloadIdentityUser"], b.role)])
    error_message = "impersonation role must be one of: roles/iam.serviceAccountTokenCreator, roles/iam.serviceAccountOpenIdTokenCreator, roles/iam.serviceAccountUser, roles/iam.workloadIdentityUser."
  }

  validation {
    condition     = alltrue([for b in values(var.impersonation) : length(setintersection(values(b.members), ["allUsers", "allAuthenticatedUsers"])) == 0])
    error_message = "impersonation must not name allUsers or allAuthenticatedUsers (module-standard MS-6.4)."
  }

  validation {
    condition     = alltrue([for b in values(var.impersonation) : length(b.members) > 0])
    error_message = "impersonation entries must name at least one member."
  }
}

variable "deletion_protection" {
  description = "When enabled, Terraform refuses to destroy the service account (deletion_policy PREVENT). A deleted account breaks every grant that names it, and a recreated one gets a new unique id."
  type = object({
    enabled = optional(bool, true)
  })
  default  = {}
  nullable = false
}
