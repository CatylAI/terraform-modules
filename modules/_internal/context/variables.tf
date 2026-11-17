variable "context" {
  description = <<-EOT
    Who and where, supplied by the calling root (module-standard MS-3):
      tenant                organisation or business unit, kebab-case
      environment           one of allowed_environments
      component             the root's component, kebab-case
      repo                  repository holding the root
      labels                extra labels; reserved keys are rejected
      allowed_environments  override of the environment vocabulary (default: contracts/environments.v1.json)
      name_prefix           override of the computed <tenant>-<environment>-<component> prefix
  EOT
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

  # Any tenant: the list of tenants an organisation allows is the root's policy, not the module's
  # (MS-15). An organisation's own list belongs in its root template.
  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,18}[a-z0-9])?$", var.context.tenant))
    error_message = "context.tenant must be kebab-case, starting with a letter, at most 20 characters."
  }

  # The default list is contracts/environments.v1.json `environments`. scripts/check_invariants.py
  # fails the gate if this literal and the contract ever differ (ADR-0002).
  validation {
    condition     = contains(coalesce(var.context.allowed_environments, ["local", "test", "dev", "uat", "staging", "prod"]), var.context.environment)
    error_message = "context.environment must be one of context.allowed_environments (default: local, test, dev, uat, staging, prod)."
  }

  validation {
    condition     = alltrue([for e in coalesce(var.context.allowed_environments, ["x"]) : can(regex("^[a-z][a-z0-9-]{0,14}$", e))])
    error_message = "context.allowed_environments entries must be kebab-case, starting with a letter, at most 15 characters."
  }

  validation {
    condition     = var.context.name_prefix == null || can(regex("^[a-z]([a-z0-9-]{0,38}[a-z0-9])?$", coalesce(var.context.name_prefix, "x")))
    error_message = "context.name_prefix must be kebab-case, starting with a letter, at most 40 characters."
  }

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,28}[a-z0-9])?$", var.context.component))
    error_message = "context.component must be kebab-case: lowercase letters, digits and hyphens, starting with a letter, at most 30 characters."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,100}$", var.context.repo))
    error_message = "context.repo must be a GitHub repository name (letters, digits, '.', '_', '-')."
  }

  validation {
    condition     = alltrue([for k in keys(var.context.labels) : can(regex("^[a-z][a-z0-9_-]{0,62}$", k))])
    error_message = "context.labels keys must start with a lowercase letter and contain only lowercase letters, digits, '_' and '-' (at most 63 characters)."
  }

  validation {
    condition     = alltrue([for v in values(var.context.labels) : can(regex("^[a-z0-9_-]{0,63}$", v))])
    error_message = "context.labels values may contain only lowercase letters, digits, '_' and '-' (at most 63 characters)."
  }

  validation {
    condition     = length(setintersection(keys(var.context.labels), ["managed-by", "tenant", "environment", "component", "repo", "module"])) == 0
    error_message = "context.labels must not set a reserved key: managed-by, tenant, environment, component, repo, module. The module sets them."
  }
}

variable "name" {
  description = "Logical name of the instance, unique within the component. Kebab-case."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]*[a-z0-9])?$", var.name))
    error_message = "name must be kebab-case: lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "module" {
  description = "Id of the calling module, <provider>-<name> (e.g. gcp-gcs-bucket). Becomes the `module` label."
  type        = string

  validation {
    condition     = can(regex("^(gcp|github|gws|aws)-[a-z0-9]+(-[a-z0-9]+)*$", var.module))
    error_message = "module must be <provider>-<name> with provider one of gcp, github, gws, aws."
  }
}

variable "name_override" {
  description = "Verbatim name for adopting a resource that predates the naming convention (ADR-0013). Leave null for new resources."
  type        = string
  default     = null
}
