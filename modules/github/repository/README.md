# github/repository

A GitHub repository with its settings, a ruleset on the default branch, issue labels and Actions
variables, every protection on by default. It follows
[the module standard](../../../docs/spec/module-standard.md).

```hcl
module "orders_service" {
  source = "git::https://github.com/CatylAI/terraform-modules.git//modules/github/repository?ref=github-repository-v0.1.0"

  context    = local.context  # validated; the name and settings do not depend on it
  name       = "orders-service" # the repository name, verbatim
  visibility = "private"        # required

  labels            = { agent-ready = { name = "agent: ready", color = "0e8a16" } }
  actions_variables = { AGENT_ENABLED = "false" }
}
```

The repository is named `var.name` exactly: no prefix, no labels (ADR-0016). Topics are an input
of their own and are never derived from `context`.

## Defaults, and how to override them

| Setting | Default | Override (in the root's tfvars) |
|---|---|---|
| Visibility | none: required | `visibility = "public" \| "private" \| "internal"` |
| Default-branch ruleset | on, enforcement `active`, on `~DEFAULT_BRANCH` | `default_branch_ruleset = { enabled = false }`, for example where an organisation ruleset already covers the branch |
| Pull request before merging | required; 1 approval; code-owner review; stale approvals dismissed | `default_branch_ruleset = { required_approving_review_count = 0, require_code_owner_review = false, ... }`. The pull request itself has no switch |
| Force pushes and branch deletion | blocked | none (turn the ruleset off instead) |
| Required status checks | none | `default_branch_ruleset = { required_status_checks = { <check name> = { integration_id = <app id> } } }`; read the warning below first |
| Ruleset bypass | nobody | `default_branch_ruleset = { bypass_actors = { <name> = { actor_type, actor_id, bypass_mode } } }` |
| Secret scanning and push protection | on | `security = { secret_scanning = false, secret_scanning_push_protection = false }` on a private repository without GitHub Secret Protection |
| Vulnerability (Dependabot) alerts | on | `security = { vulnerability_alerts = false }` |
| Destroy | archives the repository and keeps its history | `deletion_protection = { enabled = false }` deletes it on destroy |
| Features | issues on; projects, wiki, discussions, template off | `features = { wiki = true }` |
| Merging | all three methods; auto-merge off; head branch deleted after merge | `merge = { allow_merge_commit = false, ... }` |
| Private forking | off (ignored on public repositories, where forks are always allowed) | `contributions = { allow_forking = true }` |
| Initial commit | on, so the default branch exists before the ruleset protects it | `initial_commit = { enabled = false }`; always when adopting |
| Labels | none (labels the module does not list are left alone) | `labels = { <stable key> = { name, color, description } }` |
| Actions variables | none | `actions_variables = { NAME = "value" }` |

Each group is an object with optional attributes. Set one attribute and the rest keep their
defaults.

### Required status checks stall bot pull requests

The required check list is empty by default, on purpose. A pull request opened with
`GITHUB_TOKEN` (release-please, or any other workflow that opens pull requests) starts no
workflow run, so a required check **never reports** on it and the pull request
cannot merge. Before you require a check, either make sure it reports on every pull request
(open bot pull requests with a GitHub App token instead), or give that bot a bypass actor.
Pin `integration_id` to the app that must report the check (15368 is GitHub Actions), so another
app cannot satisfy it.

### Secret scanning on private repositories

On a public repository, secret scanning and push protection are free and always available. On a
private or internal repository they need GitHub Secret Protection (or the older combined GitHub
Advanced Security licence) on the owner's plan, and the API rejects the request without it. Turn
both off explicitly there. With both off, the module stops sending `security_and_analysis`, so
GitHub keeps whatever setting the repository already has.

`security.advanced_security` is unset by default and never sent. Set it to `true` only for a
private or internal repository on the combined licence, which needs Advanced Security enabled
before secret scanning. With split licensing, the API rejects any `advanced_security` value, and
on a public repository GitHub manages it itself.

### No secrets

The module takes no secret value (MS-6.2). Actions variables are plain text that anyone with read
access can read, so names containing `SECRET`, `TOKEN`, `PASSWORD`, `PASSWD` or `PRIVATE_KEY` are
rejected. Set Actions secrets out of band, outside Terraform state.

## Cost shape

Nothing is billed for a public repository: rulesets, code owners, secret scanning, push
protection and vulnerability alerts are all free there. For a private repository, cost comes from
the owner's GitHub plan, not from this module:

- rulesets and code-owner review on a private repository need a paid plan (GitHub Pro for a
  personal account, GitHub Team or higher for an organisation)
- secret scanning and push protection need GitHub Secret Protection, billed per active committer;
  turn them off with `security` where the plan lacks it
- `internal` visibility needs GitHub Enterprise Cloud
- vulnerability alerts are free on every plan

Actions minutes and storage are billed to the owner by use, and this module does not change them.

## Adopting an existing repository

The name is used verbatim, so adoption is an `import` (or a `moved` block from a raw resource)
with no rename. Set every input below to the repository's current value, then require a plan that
shows no changes:

- `name` and `visibility`
- `description`, `homepage_url` and `topics`
- `features`, `merge` and `contributions`, matched to the live settings
- `initial_commit = { enabled = false }`: import records `auto_init = false`
- `security`: on a private repository without Secret Protection, turn scanning and push
  protection off
- `default_branch_ruleset`: `{ enabled = false }` where an organisation ruleset already protects
  the branch, otherwise matched to the live repository ruleset (import it by id)
- `labels` and `actions_variables`, keyed as you want them in state

```hcl
import {
  to = module.orders_service.github_repository.this[0]
  id = "orders-service"
}
import {
  to = module.orders_service.github_repository_vulnerability_alerts.this[0]
  id = "orders-service"
}
import {
  to = module.orders_service.github_issue_label.this["agent-ready"]
  id = "orders-service:agent: ready"
}
import {
  to = module.orders_service.github_actions_variable.this["AGENT_ENABLED"]
  id = "orders-service:AGENT_ENABLED"
}
# A repository ruleset imports as "<repository>:<ruleset id>".
```

`archive_on_destroy` is a Terraform-only setting that import cannot read, so the first plan after
an `import` shows it changing to `true`. Applying it rewrites the same settings and changes
nothing on GitHub. A `moved` block from a stack that already set it shows nothing.

A label that already exists, including the labels GitHub adds to every new repository (`bug`,
`documentation`, `enhancement` and others), must be imported before the module can manage it;
creating it fails.

## Architecture Framework

| Pillar | Default | Trade-off |
|---|---|---|
| Security | Pull request and code-owner review on the default branch, force pushes and deletion blocked, no bypass actors, secret scanning and push protection, vulnerability alerts, private forking off, no secret inputs | Secret scanning on private repositories needs a paid plan, so it is an explicit off switch rather than a silent failure |
| Reliability | Destroy archives the repository and keeps its history; the default branch cannot be deleted or rewritten | An archived repository keeps its name, so recreating one with the same name needs it deleted by hand first |
| Cost optimization | Nothing paid is required: every default is free on a public repository, and paid private-repository features can be turned off | None |
| Operational excellence | One input shape across modules; labels keyed by stable names, so renaming a label is an in-place change; required checks off by default so bot pull requests do not stall | No required checks by default means CI results are advisory until a root lists them |
| Performance | None: repository settings have no performance dimension | None |
| Sustainability | Head branches are deleted after merge | None |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.14, < 2.0 |
| github | >= 6.13, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| github | >= 6.13, < 7.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| context | ../../_internal/context | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [github_actions_variable.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_variable) | resource |
| [github_issue_label.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/issue_label) | resource |
| [github_repository.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository) | resource |
| [github_repository_ruleset.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_ruleset) | resource |
| [github_repository_vulnerability_alerts.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_vulnerability_alerts) | resource |
| [github_repository.this](https://registry.terraform.io/providers/integrations/github/latest/docs/data-sources/repository) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| context | Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3). Validated, but GitHub carries no labels and the repository name ignores it (ADR-0016). | ```object({ tenant = string environment = string component = string repo = string labels = optional(map(string), {}) allowed_environments = optional(list(string)) name_prefix = optional(string) })``` | n/a | yes |
| name | Repository name, used verbatim with no prefix (ADR-0016), so an existing repository is adopted by import with no rename. Kebab-case, at most 100 characters. | `string` | n/a | yes |
| visibility | Repository visibility: public, private or internal (internal needs GitHub Enterprise Cloud). Required: it decides which security features the owner's plan can turn on. | `string` | n/a | yes |
| actions_variables | GitHub Actions repository variables, keyed by variable name. Values are plain text that anyone with read access can see, so secrets never go here (MS-6.2): set Actions secrets out of band. Names that look like secrets are rejected. | `map(string)` | `{}` | no |
| contributions | Contribution settings. Private forking off, so code in a private or internal repository stays in it; ignored for public repositories, where GitHub always allows forks. Web commit sign-off off. | ```object({ allow_forking = optional(bool, false) web_commit_signoff_required = optional(bool, false) })``` | `{}` | no |
| default_branch_ruleset | Ruleset on the default branch (~DEFAULT_BRANCH). It always requires a pull request and blocks force pushes and branch deletion; turn the ruleset off (enabled = false) rather than those rules, for example where an organisation ruleset already covers the branch. Defaults: one approval, code-owner review, stale approvals dismissed on push, no required status checks, no bypass actors.  required_status_checks is keyed by the check name. A required check never reports on a pull request opened with GITHUB_TOKEN (release-please and other bots), so requiring one stalls those pull requests. Pin integration_id to the app that must report the check. | ```object({ enabled = optional(bool, true) name = optional(string, "default-branch") required_approving_review_count = optional(number, 1) require_code_owner_review = optional(bool, true) dismiss_stale_reviews_on_push = optional(bool, true) require_last_push_approval = optional(bool, false) required_review_thread_resolution = optional(bool, false) required_status_checks = optional(map(object({ integration_id = optional(number) })), {}) strict_required_status_checks = optional(bool, false) required_linear_history = optional(bool, false) required_signatures = optional(bool, false) bypass_actors = optional(map(object({ actor_type = string actor_id = optional(number) bypass_mode = optional(string, "pull_request") })), {}) })``` | `{}` | no |
| deletion_protection | When enabled, destroying the module archives the repository and keeps its history (archive_on_destroy) instead of deleting it. Off deletes the repository on destroy. | ```object({ enabled = optional(bool, true) })``` | `{}` | no |
| description | Short description shown on the repository page. Null leaves it empty. | `string` | `null` | no |
| enabled | Set false to create nothing. Every output is then null. | `bool` | `true` | no |
| features | Repository features. Issues on; projects, wiki and discussions off, so nothing outside review holds project knowledge; template off. | ```object({ issues = optional(bool, true) projects = optional(bool, false) wiki = optional(bool, false) discussions = optional(bool, false) template = optional(bool, false) })``` | `{}` | no |
| homepage_url | URL of a page describing the project. Null leaves it empty. | `string` | `null` | no |
| initial_commit | Creates the repository with an initial commit, so the default branch exists before the ruleset protects it. Create-time only: set enabled = false when adopting an existing repository, because import records false. | ```object({ enabled = optional(bool, true) })``` | `{}` | no |
| labels | Issue labels keyed by a stable name. name defaults to the key; set it to rename a label in place without losing it from issues. color is six hex digits with no leading '#'. Additive: labels not listed here are left alone. | ```map(object({ name = optional(string) color = string description = optional(string, "") }))``` | `{}` | no |
| merge | Pull request merge settings. All three merge methods allowed, auto-merge off, head branches deleted after merge. Title and message values follow the GitHub API. | ```object({ allow_merge_commit = optional(bool, true) allow_squash_merge = optional(bool, true) allow_rebase_merge = optional(bool, true) allow_auto_merge = optional(bool, false) allow_update_branch = optional(bool, false) delete_branch_on_merge = optional(bool, true) merge_commit_title = optional(string, "MERGE_MESSAGE") merge_commit_message = optional(string, "PR_TITLE") squash_merge_commit_title = optional(string, "COMMIT_OR_PR_TITLE") squash_merge_commit_message = optional(string, "COMMIT_MESSAGES") })``` | `{}` | no |
| security | Security features. Vulnerability alerts, secret scanning and push protection are on. On a private or internal repository, secret scanning and push protection need GitHub Secret Protection or Advanced Security on the owner's plan, and the API rejects them otherwise: turn both off explicitly there. With both off, the module stops managing them and leaves GitHub's current setting as it is. advanced_security is null (not sent) by default; set it only for a private or internal repository on the older, combined Advanced Security licence. With split licensing (Secret Protection and Code Security sold separately) the API rejects it. | ```object({ vulnerability_alerts = optional(bool, true) secret_scanning = optional(bool, true) secret_scanning_push_protection = optional(bool, true) advanced_security = optional(bool) })``` | `{}` | no |
| topics | Repository topics. Not derived from context (ADR-0016). An empty set leaves the repository's existing topics alone. | `set(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| default_branch | Name of the repository's default branch, as GitHub reports it. Null when the module is disabled. |
| full_name | Repository full name, <owner>/<name>. Null when the module is disabled. |
| node_id | GraphQL node id of the repository. Null when the module is disabled. |
<!-- END_TF_DOCS -->
