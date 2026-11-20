variable "context" {
  description = "Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3). Validated, but GitHub carries no labels and the repository name ignores it (ADR-0016)."
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
  description = "Logical name of this instance, kebab-case. It is also the repository name, verbatim with no prefix (ADR-0016), unless repository_name is set."
  type        = string
}

variable "enabled" {
  description = "Set false to create nothing. Every output is then null."
  type        = bool
  default     = true
  nullable    = false
}

variable "repository_name" {
  description = "Repository name when it is not kebab-case, for example .github or a mixed-case name, so an existing repository is adopted by import with no rename. GitHub's rule: letters, digits, '.', '-' and '_', at most 100 characters. Null uses name."
  type        = string
  default     = null

  validation {
    condition     = var.repository_name == null || (can(regex("^[A-Za-z0-9._-]{1,100}$", coalesce(var.repository_name, "x"))) && !contains([".", ".."], coalesce(var.repository_name, "x")))
    error_message = "repository_name must be 1-100 characters of letters, digits, '.', '-' and '_', and must not be '.' or '..'."
  }
}

variable "visibility" {
  description = "Repository visibility: public, private or internal (internal needs GitHub Enterprise Cloud). Required: it decides which security features the owner's plan can turn on."
  type        = string

  validation {
    condition     = var.visibility != null && contains(["public", "private", "internal"], coalesce(var.visibility, "unset"))
    error_message = "visibility must be set to one of: public, private, internal."
  }
}

variable "description" {
  description = "Short description shown on the repository page. Null leaves it empty."
  type        = string
  default     = null
}

variable "homepage_url" {
  description = "URL of a page describing the project. Null leaves it empty."
  type        = string
  default     = null

  validation {
    condition     = var.homepage_url == null || can(regex("^https?://", coalesce(var.homepage_url, "x")))
    error_message = "homepage_url must start with https:// or http://."
  }
}

variable "topics" {
  description = "Repository topics. Not derived from context (ADR-0016). An empty set leaves the repository's existing topics alone."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = length(var.topics) <= 20 && alltrue([for t in var.topics : can(regex("^[a-z0-9][a-z0-9-]{0,49}$", t))])
    error_message = "topics: at most 20, each lowercase letters, digits and hyphens, starting with a letter or digit, at most 50 characters."
  }
}

variable "features" {
  description = "Repository features. Issues on; projects, wiki and discussions off, so nothing outside review holds project knowledge; template off."
  type = object({
    issues      = optional(bool, true)
    projects    = optional(bool, false)
    wiki        = optional(bool, false)
    discussions = optional(bool, false)
    template    = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "merge" {
  description = "Pull request merge settings. All three merge methods allowed, auto-merge off, head branches deleted after merge. Title and message values follow the GitHub API."
  type = object({
    allow_merge_commit          = optional(bool, true)
    allow_squash_merge          = optional(bool, true)
    allow_rebase_merge          = optional(bool, true)
    allow_auto_merge            = optional(bool, false)
    allow_update_branch         = optional(bool, false)
    delete_branch_on_merge      = optional(bool, true)
    merge_commit_title          = optional(string, "MERGE_MESSAGE")
    merge_commit_message        = optional(string, "PR_TITLE")
    squash_merge_commit_title   = optional(string, "COMMIT_OR_PR_TITLE")
    squash_merge_commit_message = optional(string, "COMMIT_MESSAGES")
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.merge.allow_merge_commit || var.merge.allow_squash_merge || var.merge.allow_rebase_merge
    error_message = "merge must allow at least one of allow_merge_commit, allow_squash_merge, allow_rebase_merge."
  }

  validation {
    condition     = contains(["PR_TITLE", "MERGE_MESSAGE"], var.merge.merge_commit_title) && contains(["PR_BODY", "PR_TITLE", "BLANK"], var.merge.merge_commit_message)
    error_message = "merge.merge_commit_title must be PR_TITLE or MERGE_MESSAGE; merge.merge_commit_message must be PR_BODY, PR_TITLE or BLANK."
  }

  validation {
    condition     = contains(["PR_TITLE", "COMMIT_OR_PR_TITLE"], var.merge.squash_merge_commit_title) && contains(["PR_BODY", "COMMIT_MESSAGES", "BLANK"], var.merge.squash_merge_commit_message)
    error_message = "merge.squash_merge_commit_title must be PR_TITLE or COMMIT_OR_PR_TITLE; merge.squash_merge_commit_message must be PR_BODY, COMMIT_MESSAGES or BLANK."
  }
}

variable "contributions" {
  description = "Contribution settings. Private forking off, so code in a private or internal repository stays in it; ignored for public repositories, where GitHub always allows forks. Web commit sign-off off."
  type = object({
    allow_forking               = optional(bool, false)
    web_commit_signoff_required = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "initial_commit" {
  description = "Creates the repository with an initial commit, so the default branch exists before the ruleset protects it. Create-time only: set enabled = false when adopting an existing repository, because import records false."
  type = object({
    enabled = optional(bool, true)
  })
  default  = {}
  nullable = false
}

variable "security" {
  description = <<-EOT
    Security features. Vulnerability alerts, secret scanning and push protection are on.
    On a private or internal repository, secret scanning and push protection need GitHub Secret
    Protection or Advanced Security on the owner's plan, and the API rejects them otherwise: turn
    both off explicitly there. With both off, the module stops managing them and leaves GitHub's
    current setting as it is. advanced_security is null (not sent) by default; set it only for a
    private or internal repository on the older, combined Advanced Security licence. With split
    licensing (Secret Protection and Code Security sold separately) the API rejects it.
  EOT
  type = object({
    vulnerability_alerts            = optional(bool, true)
    secret_scanning                 = optional(bool, true)
    secret_scanning_push_protection = optional(bool, true)
    advanced_security               = optional(bool)
  })
  default  = {}
  nullable = false

  validation {
    condition     = !var.security.secret_scanning_push_protection || var.security.secret_scanning
    error_message = "security.secret_scanning_push_protection requires security.secret_scanning = true."
  }

  validation {
    condition     = var.security.advanced_security == null || var.visibility != "public"
    error_message = "security.advanced_security cannot be set on a public repository; GitHub always enables it there."
  }
}

variable "default_branch_ruleset" {
  description = <<-EOT
    Ruleset on the default branch (~DEFAULT_BRANCH). It always requires a pull request and blocks
    force pushes and branch deletion; turn the ruleset off (enabled = false) rather than those
    rules, for example where an organisation ruleset already covers the branch. Defaults: one
    approval, code-owner review, stale approvals dismissed on push, no required status checks,
    no bypass actors.

    required_status_checks is keyed by the check name. A required check never reports on a pull
    request opened with GITHUB_TOKEN (release-please and other bots), so requiring one stalls
    those pull requests. Pin integration_id to the app that must report the check.
  EOT
  type = object({
    enabled                           = optional(bool, true)
    name                              = optional(string, "default-branch")
    required_approving_review_count   = optional(number, 1)
    require_code_owner_review         = optional(bool, true)
    dismiss_stale_reviews_on_push     = optional(bool, true)
    require_last_push_approval        = optional(bool, false)
    required_review_thread_resolution = optional(bool, false)
    required_status_checks = optional(map(object({
      integration_id = optional(number)
    })), {})
    strict_required_status_checks = optional(bool, false)
    required_linear_history       = optional(bool, false)
    required_signatures           = optional(bool, false)
    bypass_actors = optional(map(object({
      actor_type  = string
      actor_id    = optional(number)
      bypass_mode = optional(string, "pull_request")
    })), {})
  })
  default  = {}
  nullable = false

  validation {
    condition     = length(trimspace(var.default_branch_ruleset.name)) > 0
    error_message = "default_branch_ruleset.name must not be empty."
  }

  validation {
    condition     = var.default_branch_ruleset.required_approving_review_count >= 0 && var.default_branch_ruleset.required_approving_review_count <= 10 && floor(var.default_branch_ruleset.required_approving_review_count) == var.default_branch_ruleset.required_approving_review_count
    error_message = "default_branch_ruleset.required_approving_review_count must be a whole number from 0 to 10."
  }

  validation {
    condition     = alltrue([for k in keys(var.default_branch_ruleset.required_status_checks) : length(trimspace(k)) > 0])
    error_message = "default_branch_ruleset.required_status_checks keys are check names and must not be empty."
  }

  validation {
    condition     = alltrue([for a in values(var.default_branch_ruleset.bypass_actors) : contains(["RepositoryRole", "Team", "Integration", "OrganizationAdmin", "DeployKey", "EnterpriseOwner", "User"], a.actor_type)])
    error_message = "default_branch_ruleset.bypass_actors actor_type must be one of: RepositoryRole, Team, Integration, OrganizationAdmin, DeployKey, EnterpriseOwner, User."
  }

  validation {
    condition     = alltrue([for a in values(var.default_branch_ruleset.bypass_actors) : contains(["always", "pull_request", "exempt"], a.bypass_mode)])
    error_message = "default_branch_ruleset.bypass_actors bypass_mode must be one of: always, pull_request, exempt."
  }
}

variable "labels" {
  description = "Issue labels keyed by a stable name. name defaults to the key; set it to rename a label in place without losing it from issues. color is six hex digits with no leading '#'. Additive: labels not listed here are left alone."
  type = map(object({
    name        = optional(string)
    color       = string
    description = optional(string, "")
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for l in values(var.labels) : can(regex("^[0-9A-Fa-f]{6}$", l.color))])
    error_message = "labels color must be six hex digits with no leading '#', e.g. d73a4a."
  }

  validation {
    condition     = alltrue([for k, l in var.labels : length(coalesce(l.name, k)) <= 50 && length(l.description) <= 100])
    error_message = "labels name must be at most 50 characters and description at most 100."
  }

  validation {
    condition     = length(distinct([for k, l in var.labels : lower(coalesce(l.name, k))])) == length(var.labels)
    error_message = "labels must not map two keys to the same label name (GitHub compares names case-insensitively)."
  }
}

variable "actions_variables" {
  description = "GitHub Actions repository variables, keyed by variable name. Values are plain text that anyone with read access can see, so secrets never go here (MS-6.2): set Actions secrets out of band. Names that look like secrets are rejected."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for k in keys(var.actions_variables) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k)) && !startswith(upper(k), "GITHUB_")])
    error_message = "actions_variables names must be letters, digits and underscores, must not start with a digit, and must not start with GITHUB_."
  }

  validation {
    condition     = alltrue([for k in keys(var.actions_variables) : !can(regex("(?i)(SECRET|TOKEN|PASSWORD|PASSWD|PRIVATE_KEY)", k))])
    error_message = "actions_variables names must not contain SECRET, TOKEN, PASSWORD, PASSWD or PRIVATE_KEY. Variables are plain text; set secrets out of band (module-standard MS-6.2)."
  }
}

variable "deletion_protection" {
  description = "When enabled, destroying the module archives the repository and keeps its history (archive_on_destroy) instead of deleting it. Off deletes the repository on destroy."
  type = object({
    enabled = optional(bool, true)
  })
  default  = {}
  nullable = false
}
