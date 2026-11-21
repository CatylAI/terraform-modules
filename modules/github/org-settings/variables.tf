variable "context" {
  description = "Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3). Validated, but GitHub carries no labels and no setting here depends on it (ADR-0016)."
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
  description = "Logical name of this instance, kebab-case. It identifies the module call only and is never sent to GitHub: the organisation configured is always the github provider's owner (ADR-0016)."
  type        = string
}

variable "enabled" {
  description = "Set false to create nothing. Every output is then null. On an organisation this module already manages, false is refused at plan by design (prevent_destroy), because the provider's destroy writes fixed, looser values to the live organisation. To stop managing it, remove the module call and add removed blocks with destroy = false (README)."
  type        = bool
  default     = true
  nullable    = false
}

variable "billing_email" {
  description = "Billing email address of the organisation. Required, with no default: GitHub requires it on every update, and a wrong value sends invoices and plan notices to the wrong person."
  type        = string

  validation {
    condition     = var.billing_email != null && can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", coalesce(var.billing_email, "unset")))
    error_message = "billing_email must be set to an email address."
  }
}

variable "profile" {
  description = "Public profile of the organisation: display name, description, public email, blog URL, company, location and Twitter username. Null leaves a field out. The provider never sends an empty value, so neither null nor \"\" clears a field that is set on GitHub; set every field GitHub already shows to its current value, or the plan shows a change on every run."
  type = object({
    display_name     = optional(string)
    description      = optional(string)
    email            = optional(string)
    blog             = optional(string)
    company          = optional(string)
    location         = optional(string)
    twitter_username = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.profile.email == null || var.profile.email == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.profile.email))
    error_message = "profile.email must be an email address."
  }

  validation {
    condition     = length(coalesce(var.profile.description, " ")) <= 160
    error_message = "profile.description must be at most 160 characters."
  }

  validation {
    condition     = var.profile.twitter_username == null || var.profile.twitter_username == "" || can(regex("^[A-Za-z0-9_]{1,15}$", var.profile.twitter_username))
    error_message = "profile.twitter_username must be 1-15 letters, digits or underscores, with no leading '@'."
  }
}

variable "member_privileges" {
  description = <<-EOT
    What organisation members (not owners) may do. Defaults: base permission read on every
    repository; members may create private repositories but not public ones; no forking of
    private repositories; no GitHub Pages sites. create_internal_repositories applies to GitHub
    Enterprise Cloud organisations only; the provider does not send it for any other plan.
  EOT
  type = object({
    default_repository_permission = optional(string, "read")
    create_repositories           = optional(bool, true)
    create_public_repositories    = optional(bool, false)
    create_private_repositories   = optional(bool, true)
    create_internal_repositories  = optional(bool, false)
    fork_private_repositories     = optional(bool, false)
    create_pages                  = optional(bool, false)
    create_public_pages           = optional(bool, false)
    create_private_pages          = optional(bool, false)
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["read", "write", "admin", "none"], var.member_privileges.default_repository_permission)
    error_message = "member_privileges.default_repository_permission must be one of: read, write, admin, none."
  }
}

variable "features" {
  description = "Organisation features. Organisation and repository projects on (GitHub's own defaults); web commit sign-off off. web_commit_signoff_required asks for a Signed-off-by line on commits made in the web UI; it is not commit signature verification."
  type = object({
    organization_projects       = optional(bool, true)
    repository_projects         = optional(bool, true)
    web_commit_signoff_required = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "new_repository_security" {
  description = <<-EOT
    Security features turned on for repositories created after this is applied. Existing
    repositories keep their own settings; manage those per repository. Defaults: dependency
    graph, Dependabot alerts, Dependabot security updates, secret scanning and push protection
    on; Advanced Security off (paid). On private repositories, secret scanning and push
    protection need GitHub Secret Protection on the owner's plan: turn both off explicitly where
    the plan lacks it.
  EOT
  type = object({
    dependency_graph                = optional(bool, true)
    dependabot_alerts               = optional(bool, true)
    dependabot_security_updates     = optional(bool, true)
    secret_scanning                 = optional(bool, true)
    secret_scanning_push_protection = optional(bool, true)
    advanced_security               = optional(bool, false)
  })
  default  = {}
  nullable = false

  validation {
    condition     = !var.new_repository_security.secret_scanning_push_protection || var.new_repository_security.secret_scanning
    error_message = "new_repository_security.secret_scanning_push_protection requires new_repository_security.secret_scanning = true."
  }

  validation {
    condition     = !var.new_repository_security.dependabot_alerts || var.new_repository_security.dependency_graph
    error_message = "new_repository_security.dependabot_alerts requires new_repository_security.dependency_graph = true."
  }

  validation {
    condition     = !var.new_repository_security.dependabot_security_updates || var.new_repository_security.dependabot_alerts
    error_message = "new_repository_security.dependabot_security_updates requires new_repository_security.dependabot_alerts = true."
  }
}

variable "actions" {
  description = <<-EOT
    Which repositories may run GitHub Actions, and which actions they may use. Defaults: every
    repository may run Actions; only GitHub-owned actions, actions from verified Marketplace
    creators, the organisation's own actions and patterns_allowed may run (allowed_actions =
    "selected").

    selected_repository_ids is required when enabled_repositories = "selected", and must be empty
    otherwise. patterns_allowed is accepted only with allowed_actions = "selected".

    sha_pinning_required is null (not managed) by default: turning it on fails every workflow that
    uses an action by tag, and the provider never sends false, so it cannot be turned off again
    through Terraform. Set it to true only once every workflow pins actions by full commit SHA.
  EOT
  type = object({
    enabled_repositories    = optional(string, "all")
    selected_repository_ids = optional(set(number), [])
    allowed_actions         = optional(string, "selected")
    github_owned_allowed    = optional(bool, true)
    verified_allowed        = optional(bool, true)
    patterns_allowed        = optional(set(string), [])
    sha_pinning_required    = optional(bool)
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["all", "none", "selected"], var.actions.enabled_repositories)
    error_message = "actions.enabled_repositories must be one of: all, none, selected."
  }

  validation {
    condition     = contains(["all", "local_only", "selected"], var.actions.allowed_actions)
    error_message = "actions.allowed_actions must be one of: all, local_only, selected."
  }

  validation {
    condition     = (var.actions.enabled_repositories == "selected") == (length(var.actions.selected_repository_ids) > 0)
    error_message = "actions.selected_repository_ids must list at least one repository id when enabled_repositories = \"selected\", and must be empty otherwise."
  }

  validation {
    condition     = alltrue([for id in var.actions.selected_repository_ids : id > 0 && floor(id) == id])
    error_message = "actions.selected_repository_ids must be positive whole numbers (numeric repository ids, not names)."
  }

  validation {
    condition     = var.actions.allowed_actions == "selected" || length(var.actions.patterns_allowed) == 0
    error_message = "actions.patterns_allowed is used only with allowed_actions = \"selected\"; clear it or set allowed_actions = \"selected\"."
  }

  validation {
    condition     = alltrue([for p in var.actions.patterns_allowed : can(regex("^\\S+$", p))])
    error_message = "actions.patterns_allowed entries must be non-empty and contain no whitespace, e.g. acme/deploy-action@v2 or acme/*."
  }
}

variable "workflow_permissions" {
  description = "Default permissions of the GITHUB_TOKEN in every repository of the organisation. Defaults: read-only token, and workflows may not approve pull requests. A repository can still raise its own token's permissions in a workflow's permissions block."
  type = object({
    default_workflow_permissions     = optional(string, "read")
    can_approve_pull_request_reviews = optional(bool, false)
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["read", "write"], var.workflow_permissions.default_workflow_permissions)
    error_message = "workflow_permissions.default_workflow_permissions must be read or write."
  }
}
