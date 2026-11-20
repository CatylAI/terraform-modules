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
  description = "Logical name of this pool, unique within the component. Kebab-case. The pool id is <prefix>-<name>, where prefix is context.name_prefix or <tenant>-<environment>-<component>; the API limits it to 4-32 characters."
  type        = string
}

variable "enabled" {
  description = "Set false to create nothing. Every output is then null."
  type        = bool
  default     = true
  nullable    = false
}

variable "name_override" {
  description = "Verbatim pool id, only for adopting a pool that predates the naming convention (ADR-0013). Leave null for new pools."
  type        = string
  default     = null
}

variable "project_id" {
  description = "Project that owns the pool."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a GCP project id: 6-30 characters, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "oidc_providers" {
  description = <<-EOT
    OIDC providers in the pool, keyed by provider id (4-32 characters of [a-z0-9-], not starting
    with gcp-). Each provider takes:
      issuer_uri           https URL of the token issuer
      attribute_mapping    Google attribute => CEL expression; must map google.subject
      attribute_condition  CEL expression every token must satisfy; required and non-empty
      allowed_audiences    accepted aud values (at most 10); empty means the provider's own resource name
      jwks_json            the issuer's public JWKS, for an issuer Google cannot reach (a private cluster)
      disabled             stops new token exchanges without deleting the provider
    A GitHub Actions issuer (https://token.actions.githubusercontent.com, or an enterprise issuer
    under it) must map attribute.repository_owner_id and reference assertion.repository_owner_id
    in its condition, so trust is pinned to the immutable numeric owner id.
  EOT
  type = map(object({
    issuer_uri          = string
    attribute_mapping   = map(string)
    attribute_condition = string
    allowed_audiences   = optional(list(string), [])
    jwks_json           = optional(string)
    disabled            = optional(bool, false)
  }))
  nullable = false

  validation {
    condition     = alltrue([for p in values(var.oidc_providers) : can(regex("^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[^\\s?#]*)?$", p.issuer_uri))])
    error_message = "oidc_providers issuer_uri must be an https URL with no query or fragment."
  }

  validation {
    condition     = alltrue([for p in values(var.oidc_providers) : try(length(trimspace(p.attribute_condition)) > 0 && length(p.attribute_condition) <= 4096, false)])
    error_message = "oidc_providers attribute_condition is required and must be non-empty (at most 4096 characters); a provider without one trusts every subject on its issuer."
  }

  validation {
    condition     = alltrue([for p in values(var.oidc_providers) : contains(keys(p.attribute_mapping), "google.subject")])
    error_message = "oidc_providers attribute_mapping must map google.subject; the API requires it for OIDC providers."
  }

  validation {
    condition     = alltrue([for p in values(var.oidc_providers) : alltrue([for k in keys(p.attribute_mapping) : can(regex("^(google\\.[a-z_]+|attribute\\.[a-z0-9_]{1,100})$", k))])])
    error_message = "oidc_providers attribute_mapping keys must be google.<name> or attribute.<name>, where a custom name is 1-100 characters of [a-z0-9_]."
  }

  # The GitHub guard. It matches the public issuer and any enterprise issuer under it
  # (https://token.actions.githubusercontent.com/<enterprise>), which carry the same claims. It is
  # a textual check: it proves the condition names the owner id, not that the expression is sound.
  validation {
    condition = alltrue([for p in values(var.oidc_providers) :
      !can(regex("^https://token\\.actions\\.githubusercontent\\.com(/|$)", lower(p.issuer_uri))) || (
        can(regex("assertion\\.repository_owner_id\\b", p.attribute_condition)) &&
        contains(keys(p.attribute_mapping), "attribute.repository_owner_id")
      )
    ])
    error_message = "oidc_providers on the GitHub Actions issuer must reference assertion.repository_owner_id in attribute_condition and map attribute.repository_owner_id; the numeric owner id survives a rename, an owner name does not."
  }

  validation {
    condition     = alltrue([for p in values(var.oidc_providers) : length(p.allowed_audiences) <= 10 && alltrue([for a in p.allowed_audiences : length(a) > 0 && length(a) <= 256])])
    error_message = "oidc_providers allowed_audiences takes at most 10 audiences of 1-256 characters each."
  }

  validation {
    condition     = alltrue([for p in values(var.oidc_providers) : p.jwks_json == null || try(length(jsondecode(coalesce(p.jwks_json, "{}")).keys) > 0, false)])
    error_message = "oidc_providers jwks_json must be a JWKS document: JSON with a non-empty keys array."
  }
}

variable "deletion_protection" {
  description = "When enabled, Terraform refuses to destroy the pool (deletion_policy PREVENT). Providers are never protected, so revoking trust is never blocked; set a provider's disabled for an immediate stop."
  type = object({
    enabled = optional(bool, true)
  })
  default  = {}
  nullable = false
}
