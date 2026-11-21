variable "context" {
  description = "Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3). Validated, but not applied: GitHub resources carry no labels and no prefix (ADR-0016)."
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
  description = "Logical name of this instance, unique within the component. Kebab-case. It identifies the module call (for example release-app) and is not sent to GitHub: repositories are named by repositories, verbatim (ADR-0016)."
  type        = string
}

variable "enabled" {
  description = "Set false to create nothing. Every output is then null."
  type        = bool
  default     = true
  nullable    = false
}

variable "installation_id" {
  description = "Numeric id of the GitHub App installation, the number at the end of the installation's settings URL (.../settings/installations/<id>). The App must already be installed on the provider's owner with access to selected repositories. Required; null is accepted only when enabled = false, so a root can drive both from one optional variable."
  type        = number

  validation {
    condition     = var.installation_id == null ? !var.enabled : try(var.installation_id >= 1 && floor(var.installation_id) == var.installation_id, false)
    error_message = "installation_id must be a positive whole number (the installation's numeric id). It may be null only when enabled = false."
  }
}

variable "repositories" {
  description = "Names of the repositories to attach to the installation, without the owner (orders-service, not acme/orders-service). The owner is the provider's. Each name is a stable for_each key, so adding or removing one never touches the others. Additive: repositories attached outside this module are left alone."
  type        = set(string)
  nullable    = false

  validation {
    condition     = !var.enabled || length(var.repositories) > 0
    error_message = "repositories must name at least one repository while enabled; set enabled = false to attach none."
  }

  validation {
    condition     = alltrue([for r in var.repositories : can(regex("^[A-Za-z0-9._-]{1,100}$", r)) && !contains([".", ".."], r)])
    error_message = "repositories must be repository names without the owner: 1-100 letters, digits, '.', '_' or '-', and not '.' or '..'."
  }

  validation {
    condition     = length(distinct([for r in var.repositories : lower(r)])) == length(var.repositories)
    error_message = "repositories must not list the same repository twice in different case (GitHub compares names case-insensitively)."
  }
}
