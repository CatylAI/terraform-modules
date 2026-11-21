variable "context" {
  description = "Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3). Validated, but GitHub carries no labels and the ruleset name ignores it (ADR-0016)."
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
  description = "Logical name of this instance, kebab-case. It is also the ruleset name, verbatim with no prefix (ADR-0016), unless ruleset_name is set."
  type        = string
}

variable "enabled" {
  description = "Set false to create nothing. Every output is then null."
  type        = bool
  default     = true
  nullable    = false
}

variable "ruleset_name" {
  description = "Ruleset name when it is not kebab-case, for example one with capitals, spaces or a colon, so an existing ruleset is adopted by import with no rename. At most 100 characters. Null uses name."
  type        = string
  default     = null

  validation {
    condition     = var.ruleset_name == null || (length(trimspace(coalesce(var.ruleset_name, "x"))) > 0 && length(coalesce(var.ruleset_name, "x")) <= 100)
    error_message = "ruleset_name must not be blank and must be at most 100 characters."
  }
}

variable "target" {
  description = "What the ruleset protects: branch or tag. Required. The github provider does not support the repository target (repository deletion, transfer and visibility rules) or, in this module, push rulesets."
  type        = string

  validation {
    condition     = var.target != null && contains(["branch", "tag"], coalesce(var.target, "unset"))
    error_message = "target must be set to branch or tag. The repository target (repository_delete, repository_transfer, repository_visibility rules) has no github provider support; push rulesets are out of this module's scope."
  }
}

variable "enforcement" {
  description = "Enforcement level: active (enforced), evaluate (report only; GitHub Enterprise) or disabled."
  type        = string
  default     = "active"
  nullable    = false

  validation {
    condition     = contains(["active", "evaluate", "disabled"], var.enforcement)
    error_message = "enforcement must be one of: active, evaluate, disabled."
  }
}

variable "conditions" {
  description = <<-EOT
    Which repositories and refs the ruleset applies to. Required: an organisation ruleset's reach
    is the caller's decision. repository_name patterns match repository names (~ALL matches every
    repository); ref_name patterns match refs (~DEFAULT_BRANCH, ~ALL, refs/heads/<pattern>,
    refs/tags/<pattern>) and default to the default branch. Lists keep their order, as GitHub
    stores them.
  EOT
  type = object({
    ref_name = optional(object({
      include = optional(list(string), ["~DEFAULT_BRANCH"])
      exclude = optional(list(string), [])
    }), {})
    repository_name = object({
      include = list(string)
      exclude = optional(list(string), [])
    })
  })
  nullable = false

  validation {
    condition     = length(var.conditions.repository_name.include) > 0 && length(var.conditions.ref_name.include) > 0
    error_message = "conditions.repository_name.include and conditions.ref_name.include must each list at least one pattern; an empty include matches nothing."
  }

  validation {
    condition = alltrue([
      for p in concat(
        var.conditions.repository_name.include, var.conditions.repository_name.exclude,
        var.conditions.ref_name.include, var.conditions.ref_name.exclude,
      ) : length(trimspace(p)) > 0
    ])
    error_message = "conditions patterns must not be blank."
  }
}

variable "bypass_actors" {
  description = "Actors who may bypass the ruleset, keyed by a stable name. actor_id is the team, app (integration) or repository role id; leave it unset for OrganizationAdmin, EnterpriseOwner and DeployKey, which have none. bypass_mode: always, pull_request (only by merging a pull request) or exempt. Nobody bypasses by default."
  type = map(object({
    actor_type  = string
    actor_id    = optional(number)
    bypass_mode = optional(string, "pull_request")
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for a in values(var.bypass_actors) : contains(["Integration", "OrganizationAdmin", "RepositoryRole", "Team", "DeployKey", "EnterpriseOwner"], a.actor_type)])
    error_message = "bypass_actors actor_type must be one of: Integration, OrganizationAdmin, RepositoryRole, Team, DeployKey, EnterpriseOwner."
  }

  validation {
    condition     = alltrue([for a in values(var.bypass_actors) : contains(["always", "pull_request", "exempt"], a.bypass_mode)])
    error_message = "bypass_actors bypass_mode must be one of: always, pull_request, exempt."
  }

  validation {
    condition     = alltrue([for a in values(var.bypass_actors) : contains(["OrganizationAdmin", "EnterpriseOwner", "DeployKey"], a.actor_type) == (a.actor_id == null)])
    error_message = "bypass_actors actor_id must be unset for OrganizationAdmin, EnterpriseOwner and DeployKey (GitHub ignores it, so the plan would never settle), and set for Integration, RepositoryRole and Team."
  }
}

variable "rules" {
  description = <<-EOT
    The ruleset's rules. Deletion and force pushes (non_fast_forward) are blocked by default; the
    rest are off. pull_request is absent by default: pull_request = {} requires a pull request with
    one approval and code-owner review, dismissing stale approvals, and enabled = false removes it.

    required_status_checks is keyed by the check context, for example "ci / test". A required check
    never reports on a pull request opened with GITHUB_TOKEN (release-please and other bots), so
    requiring one stalls those pull requests. Pin integration_id to the app that must report the
    check.
  EOT
  type = object({
    deletion                = optional(bool, true)
    non_fast_forward        = optional(bool, true)
    creation                = optional(bool, false)
    update                  = optional(bool, false)
    required_linear_history = optional(bool, false)
    required_signatures     = optional(bool, false)
    pull_request = optional(object({
      enabled                           = optional(bool, true)
      required_approving_review_count   = optional(number, 1)
      require_code_owner_review         = optional(bool, true)
      dismiss_stale_reviews_on_push     = optional(bool, true)
      require_last_push_approval        = optional(bool, false)
      required_review_thread_resolution = optional(bool, false)
    }))
    required_status_checks = optional(map(object({
      integration_id = optional(number)
    })), {})
    strict_required_status_checks = optional(bool, false)
  })
  default  = {}
  nullable = false

  validation {
    condition = var.rules.pull_request == null || (
      try(var.rules.pull_request.required_approving_review_count >= 0 && var.rules.pull_request.required_approving_review_count <= 10 && floor(var.rules.pull_request.required_approving_review_count) == var.rules.pull_request.required_approving_review_count, false)
    )
    error_message = "rules.pull_request.required_approving_review_count must be a whole number from 0 to 10."
  }

  validation {
    condition     = alltrue([for k in keys(var.rules.required_status_checks) : length(trimspace(k)) > 0])
    error_message = "rules.required_status_checks keys are check contexts and must not be blank."
  }

  validation {
    condition = anytrue([
      var.rules.deletion, var.rules.non_fast_forward, var.rules.creation, var.rules.update,
      var.rules.required_linear_history, var.rules.required_signatures,
      try(var.rules.pull_request.enabled, false), length(var.rules.required_status_checks) > 0,
    ])
    error_message = "rules must turn on at least one rule; a ruleset with none protects nothing."
  }
}
