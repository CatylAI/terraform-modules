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
  description = "Logical name of this set of services, unique within the component. Kebab-case. API enablements have no name of their own, so it identifies the module instance only."
  type        = string
}

variable "enabled" {
  description = "Set false to create nothing. The services output is then empty."
  type        = bool
  default     = true
  nullable    = false
}

variable "project_id" {
  description = "Existing project in which to enable the APIs."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a GCP project id: 6-30 characters, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "services" {
  description = "APIs to enable, keyed by a stable name. service is the full API name (e.g. iam.googleapis.com). Removing an entry stops managing the API and leaves it enabled. disable_on_destroy = true makes removal disable the API; disable_dependent_services = true (only with disable_on_destroy) also disables every enabled API that depends on it."
  type = map(object({
    service                    = string
    disable_on_destroy         = optional(bool, false)
    disable_dependent_services = optional(bool, false)
  }))
  nullable = false

  validation {
    condition     = alltrue([for s in values(var.services) : can(regex("^[a-z][a-z0-9.-]*\\.googleapis\\.com$", s.service))])
    error_message = "services service must be a full API name ending in .googleapis.com (e.g. iam.googleapis.com)."
  }

  validation {
    condition     = length(distinct([for s in values(var.services) : s.service])) == length(var.services)
    error_message = "services must name each API once; two entries for the same service would manage one API twice."
  }

  validation {
    condition     = alltrue([for s in values(var.services) : !s.disable_dependent_services || s.disable_on_destroy])
    error_message = "services disable_dependent_services requires disable_on_destroy = true on the same entry."
  }
}
