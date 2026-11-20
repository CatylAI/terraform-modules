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
  description = "Logical name of this instance, unique within the component. Kebab-case. It identifies the module call (for example orders-production) and is not sent to GitHub; the environment is named by environment_name."
  type        = string
}

variable "enabled" {
  description = "Set false to create nothing. Every output is then null."
  type        = bool
  default     = true
  nullable    = false
}

variable "repository" {
  description = "Name of the existing repository that owns the environment, without the owner (orders-service, not acme/orders-service). The owner is the provider's."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,100}$", var.repository))
    error_message = "repository must be a repository name without the owner: 1-100 letters, digits, '.', '_' or '-'."
  }
}

variable "environment_name" {
  description = "The GitHub environment's own name, used verbatim (for example production). Workflows reference it in `environment:`. It is unrelated to the environment in context, which no module reads (MS-3.5, ADR-0016). GitHub treats environment names case-insensitively."
  type        = string

  validation {
    condition     = length(var.environment_name) >= 1 && length(var.environment_name) <= 255 && trimspace(var.environment_name) == var.environment_name
    error_message = "environment_name must be 1-255 characters with no leading or trailing whitespace."
  }
}

variable "reviewers" {
  description = "Required reviewers, as numeric GitHub user and team ids. One approval releases the job, and the person who triggered it cannot approve it (self-review is always blocked when reviewers are set). At most six users and teams in total. On GitHub Free, Pro and Team, required reviewers work only in public repositories; leave this empty on a private repository and rely on the default policy, which deploys only from explicitly named branches (main), with approval at the pull request that changes them."
  type = object({
    users = optional(set(number), [])
    teams = optional(set(number), [])
  })
  default  = {}
  nullable = false

  validation {
    condition     = length(var.reviewers.users) + length(var.reviewers.teams) <= 6
    error_message = "reviewers may list at most six users and teams in total (GitHub's limit)."
  }

  validation {
    condition     = alltrue([for id in setunion(var.reviewers.users, var.reviewers.teams) : id >= 1 && floor(id) == id])
    error_message = "reviewers users and teams must be positive whole-number GitHub ids, not logins or slugs."
  }
}

variable "deployment_branch_policy" {
  description = "Which refs may deploy. The default allows only the branch named main. branches and tags are name patterns (GitHub's 'selected branches and tags'). protected_branches = true instead allows branches with classic branch protection, and requires branches = [] and tags = []. With protected_branches = false and no patterns, any ref may deploy. Without reviewers, only explicit branch names are accepted: no protected_branches, no wildcards (*, ?, [) and no tags, so the environment is never left open."
  type = object({
    protected_branches = optional(bool, false)
    branches           = optional(set(string), ["main"])
    tags               = optional(set(string), [])
  })
  default  = {}
  nullable = false

  # Without reviewers the branch names are the only gate, so each rule below closes a way for an
  # unreviewed ref to deploy. GitHub lets every branch deploy under protected_branches when no
  # classic branch protection rule exists, and rulesets are not documented to count.
  validation {
    condition     = length(var.reviewers.users) + length(var.reviewers.teams) > 0 || !var.deployment_branch_policy.protected_branches
    error_message = "deployment_branch_policy.protected_branches requires reviewers: GitHub lets every branch deploy when no classic branch protection rule exists, and rulesets are not documented to count. Name the branches in deployment_branch_policy.branches instead."
  }

  validation {
    condition     = length(var.reviewers.users) + length(var.reviewers.teams) > 0 || var.deployment_branch_policy.protected_branches || length(var.deployment_branch_policy.branches) > 0
    error_message = "deployment_branch_policy.branches must name at least one branch when no reviewers are set; otherwise any ref could deploy unreviewed."
  }

  validation {
    condition     = length(var.reviewers.users) + length(var.reviewers.teams) > 0 || alltrue([for b in var.deployment_branch_policy.branches : !can(regex("[*?\\[]", b))])
    error_message = "deployment_branch_policy.branches must be exact branch names, with no '*', '?' or '[', when no reviewers are set: anyone who can push a matching new branch could deploy unreviewed."
  }

  validation {
    condition     = length(var.reviewers.users) + length(var.reviewers.teams) > 0 || length(var.deployment_branch_policy.tags) == 0
    error_message = "deployment_branch_policy.tags requires reviewers: tags are not protected by branch rules, so anyone who can push a tag could deploy unreviewed."
  }

  validation {
    condition     = !var.deployment_branch_policy.protected_branches || (length(var.deployment_branch_policy.branches) == 0 && length(var.deployment_branch_policy.tags) == 0)
    error_message = "deployment_branch_policy.protected_branches = true requires branches = [] and tags = []; GitHub accepts protected branches or name patterns, not both."
  }

  validation {
    condition     = alltrue([for p in setunion(var.deployment_branch_policy.branches, var.deployment_branch_policy.tags) : length(trimspace(p)) > 0 && trimspace(p) == p])
    error_message = "deployment_branch_policy branches and tags must be non-empty patterns with no leading or trailing whitespace."
  }
}

variable "admin_bypass" {
  description = "Whether repository administrators can bypass the environment's protection rules. Off by default."
  type = object({
    enabled = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "variables" {
  description = "Environment variables (vars context), keyed by variable name. Plain configuration only: values are stored in clear in state and shown in plans. Secrets are never passed here; set environment secrets out of band (MS-6.2). Names are upper case, letters, digits and '_', not starting with a digit or GITHUB_; at most 100 per environment."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for k in keys(var.variables) : can(regex("^[A-Z_][A-Z0-9_]*$", k)) && !startswith(k, "GITHUB_")])
    error_message = "variables keys must be upper-case letters, digits and '_', must not start with a digit, and must not start with GITHUB_ (GitHub stores names upper case, so a lower-case name diffs on every plan)."
  }

  validation {
    condition     = alltrue([for k in keys(var.variables) : !can(regex("(PASSWORD|PASSWD|SECRET|TOKEN|PRIVATE_KEY)", k))])
    error_message = "variables keys must not name a secret (PASSWORD, PASSWD, SECRET, TOKEN, PRIVATE_KEY): variables are plain text. Set secrets out of band (module-standard MS-6.2)."
  }

  validation {
    condition     = length(var.variables) <= 100
    error_message = "variables may hold at most 100 entries (GitHub's per-environment limit)."
  }
}
