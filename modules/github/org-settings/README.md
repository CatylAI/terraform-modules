# github/org-settings

A GitHub organisation's settings and its Actions permissions, every protection on by default:
member privileges, security features for new repositories, which actions may run, and the default
`GITHUB_TOKEN` permissions. It follows [the module standard](../../../docs/spec/module-standard.md).

```hcl
module "org_settings" {
  source = "git::https://github.com/CatylAI/terraform-modules.git//modules/github/org-settings?ref=github-org-settings-v0.1.0"

  context       = local.context        # validated; no setting depends on it
  name          = "org-settings"       # this module call; never sent to GitHub
  billing_email = "billing@example.com" # required, no default
}
```

## Which organisation

Every resource configures the github provider's `owner`, which must be an organisation. The
module takes no organisation name: `name` identifies the module call only and is validated as
kebab-case, and `context` is validated but never sent (ADR-0016). The workflow-permissions API
needs the organisation's login, so the module reads it from the Actions permissions resource,
whose id is the provider owner's login. All three resources therefore always target the same
organisation.

## Defaults, and how to override them

| Setting | Default | Override (in the root's tfvars) |
|---|---|---|
| Billing email | none: required | `billing_email = "billing@example.com"` |
| Base repository permission for members | `read` | `member_privileges = { default_repository_permission = "none" \| "write" \| "admin" }` |
| Members create public repositories | off | `member_privileges = { create_public_repositories = true }` |
| Members create private repositories | on | `member_privileges = { create_private_repositories = false }`, or `create_repositories = false` |
| Members create internal repositories | off (Enterprise Cloud only) | `member_privileges = { create_internal_repositories = true }` |
| Members fork private repositories | off | `member_privileges = { fork_private_repositories = true }` |
| Members publish GitHub Pages | off, public and private | `member_privileges = { create_pages = true, create_public_pages = true }` |
| Organisation and repository projects | on (GitHub's defaults) | `features = { repository_projects = false }` |
| Web commit sign-off | off | `features = { web_commit_signoff_required = true }` |
| New repositories: dependency graph, Dependabot alerts, Dependabot security updates | on | `new_repository_security = { dependabot_security_updates = false }` |
| New repositories: secret scanning and push protection | on | `new_repository_security = { secret_scanning = false, secret_scanning_push_protection = false }` without GitHub Secret Protection |
| New repositories: Advanced Security | off (paid) | `new_repository_security = { advanced_security = true }` |
| Repositories that may run Actions | all | `actions = { enabled_repositories = "selected", selected_repository_ids = [...] }`, or `"none"` |
| Actions that may run | selected: GitHub-owned, verified Marketplace creators, the organisation's own | `actions = { allowed_actions = "all" \| "local_only" }`, or `patterns_allowed = ["acme/*"]`, `verified_allowed = false` |
| Require actions pinned by SHA | not managed | `actions = { sha_pinning_required = true }`; read the warning below first |
| Default `GITHUB_TOKEN` permissions | read | `workflow_permissions = { default_workflow_permissions = "write" }` |
| Workflows approve pull requests | off | `workflow_permissions = { can_approve_pull_request_reviews = true }` |
| Profile (display name, description, public email, blog, company, location, Twitter) | not sent | `profile = { display_name = "Acme", ... }` |

Each group is an object with optional attributes. Set one attribute and the rest keep their
defaults.

Validation rejects combinations GitHub rejects or silently ignores: push protection without secret
scanning, Dependabot alerts without the dependency graph, Dependabot security updates without
alerts, a repository list unless `enabled_repositories = "selected"` (and `"selected"` without
one), and `patterns_allowed` unless `allowed_actions = "selected"`.

### Settings this module does not manage

- **Two-factor authentication.** The github provider (6.x) cannot set the organisation's
  two-factor requirement; GitHub's REST API exposes it read-only, and the `github_organization`
  data source reports it as `two_factor_requirement_enabled`. Turn it on in the organisation's
  settings page. Doing so removes every member, outside collaborator and bot account without 2FA,
  so check the member list first.
- **Organisation Actions variables and secrets.** They are separate resources
  (`github_actions_organization_variable`) and a separate concern. Secrets never belong in a
  module (MS-6.2).
- **Organisation rulesets, teams and members.** Separate resources and separate modules.

### SHA pinning cannot be turned off through Terraform

`actions.sha_pinning_required` is null by default, so the module leaves GitHub's current setting
alone. Turning it on fails every workflow that uses an action or reusable workflow by tag or
branch (`actions/checkout@v4`). The provider never sends `false`, so once it is on, only the
organisation's settings page can turn it off; setting `false` here then shows a change on every
plan without applying it. Turn it on only after every workflow pins by full commit SHA.

### Secret scanning for new private repositories

On public repositories, secret scanning and push protection are free. On private repositories they
need GitHub Secret Protection (or the older combined GitHub Advanced Security licence) on the
organisation's plan. Turn both off explicitly where the plan lacks it. These settings apply only
to repositories created afterwards; GitHub now steers organisations towards code security
configurations for existing repositories, which this module does not manage. The repository
module (`github/repository`) sets each repository's own features explicitly.

### Destroy does not restore anything

None of these resources can be deleted on GitHub, so the provider "deletes" each one by writing
fixed values:

- organisation settings: the billing email becomes a placeholder address
- Actions permissions: all repositories, all actions (the loosest policy)
- workflow permissions: read-only token, no pull request approval

So all three resources carry a literal `lifecycle { prevent_destroy = true }`. Destroying the
module, deleting the module call, or setting `enabled = false` on an organisation the module
already manages is refused at plan, by design. `enabled = false` from the start still creates
nothing.

To stop managing an organisation, remove the module call and add `removed` blocks, which forget
the resources and leave GitHub as it is:

```hcl
removed {
  from = module.org_settings.github_organization_settings.this
  lifecycle {
    destroy = false
  }
}
removed {
  from = module.org_settings.github_actions_organization_permissions.this
  lifecycle {
    destroy = false
  }
}
removed {
  from = module.org_settings.github_actions_organization_workflow_permissions.this
  lifecycle {
    destroy = false
  }
}
```

Why `prevent_destroy` is a literal here, with no `deletion_protection` knob: these are live
singletons that cannot be removed, and the provider's destroy writes values back to them instead,
including insecure ones (all actions allowed, a placeholder billing email). The provider offers no
native protection setting a variable could drive, and Terraform cannot drive `prevent_destroy` from
a variable (MS-5.4). A stray `enabled = false` or refactor must fail loudly at plan rather than
quietly loosen a live organisation on apply.

### No secrets

The module takes no secret value (MS-6.2). The billing email and the public profile email are
contact details, not credentials.

## Cost shape

Nothing is billed by this module. Settings on paid features need the matching plan, and the API
rejects them otherwise:

- secret scanning and push protection for new private repositories need GitHub Secret Protection,
  billed per active committer; turn them off with `new_repository_security` where the plan lacks it
- `advanced_security` needs the combined GitHub Advanced Security licence
- internal repositories and private Pages need GitHub Enterprise Cloud

Actions minutes and storage are billed to the organisation by use. Restricting which repositories
and actions may run reduces what can consume them, but the module sets no spending limit.

## Adopting an existing organisation

Organisation settings always exist, so adoption is an `import` (or a `moved` block from raw
resources that were already imported) and never a create. Set every input below to the
organisation's current value, then require a plan that shows no changes:

- `billing_email`
- `profile`: every field GitHub shows, exactly. A field left null keeps its value on GitHub but
  plans as a change on every run
- `member_privileges`, `features` and `new_repository_security`, matched to the live settings.
  Each looser live value is an explicit override of a secure default
- `actions`: the live `enabled_repositories`, `allowed_actions` and, when `"selected"`, the
  live allow list. Leave `sha_pinning_required` null unless it is already on
- `workflow_permissions`, matched to the live token permissions

From raw resources already in state:

```hcl
moved {
  from = github_organization_settings.this
  to   = module.org_settings.github_organization_settings.this[0]
}
moved {
  from = github_actions_organization_permissions.this
  to   = module.org_settings.github_actions_organization_permissions.this[0]
}
moved {
  from = github_actions_organization_workflow_permissions.this
  to   = module.org_settings.github_actions_organization_workflow_permissions.this[0]
}
```

From nothing:

```hcl
import {
  to = module.org_settings.github_organization_settings.this[0]
  id = "123456789" # the organisation's numeric id: gh api orgs/acme --jq .id
}
import {
  to = module.org_settings.github_actions_organization_permissions.this[0]
  id = "acme" # the organisation's login
}
import {
  to = module.org_settings.github_actions_organization_workflow_permissions.this[0]
  id = "acme"
}
```

The provider reads the allow list (`allowed_actions_config`) back only when the organisation's
policy is `"selected"`, so an organisation on `"all"` or `"local_only"` imports with no allow list
and the module sends none.

## Architecture Framework

| Pillar | Default | Trade-off |
|---|---|---|
| Security | Members read-only on repositories; no public repositories, private forks or Pages from members; secret scanning, push protection, dependency graph and Dependabot on for new repositories; Actions limited to GitHub-owned and verified actions; read-only `GITHUB_TOKEN` that cannot approve pull requests; no secret inputs | Restricting actions blocks third-party actions from unverified creators until a root lists them in `patterns_allowed`. SHA pinning stays off by default, because the provider cannot reverse it |
| Reliability | One resource per setting family, so a failed Actions call leaves organisation settings alone; workflow permissions always target the provider's owner; destroy is refused at plan (`prevent_destroy`) | Retiring the module takes `removed` blocks rather than `enabled = false` |
| Cost optimization | Nothing paid is required; paid features (Advanced Security, Secret Protection on private repositories) are explicit | None |
| Operational excellence | One input shape across modules; adoption by `moved` or `import` with every looser live value written as an explicit override | A read-only token and restricted actions can break workflows that relied on the looser defaults; the adoption overrides keep them working until each is tightened |
| Performance | None: organisation settings have no performance dimension | None |
| Sustainability | Restricting which repositories and actions run reduces wasted Actions minutes | None |

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
| [github_actions_organization_permissions.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_organization_permissions) | resource |
| [github_actions_organization_workflow_permissions.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_organization_workflow_permissions) | resource |
| [github_organization_settings.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/organization_settings) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| billing_email | Billing email address of the organisation. Required, with no default: GitHub requires it on every update, and a wrong value sends invoices and plan notices to the wrong person. | `string` | n/a | yes |
| context | Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3). Validated, but GitHub carries no labels and no setting here depends on it (ADR-0016). | ```object({ tenant = string environment = string component = string repo = string labels = optional(map(string), {}) allowed_environments = optional(list(string)) name_prefix = optional(string) })``` | n/a | yes |
| name | Logical name of this instance, kebab-case. It identifies the module call only and is never sent to GitHub: the organisation configured is always the github provider's owner (ADR-0016). | `string` | n/a | yes |
| actions | Which repositories may run GitHub Actions, and which actions they may use. Defaults: every repository may run Actions; only GitHub-owned actions, actions from verified Marketplace creators, the organisation's own actions and patterns_allowed may run (allowed_actions = "selected").  selected_repository_ids is required when enabled_repositories = "selected", and must be empty otherwise. patterns_allowed is accepted only with allowed_actions = "selected".  sha_pinning_required is null (not managed) by default: turning it on fails every workflow that uses an action by tag, and the provider never sends false, so it cannot be turned off again through Terraform. Set it to true only once every workflow pins actions by full commit SHA. | ```object({ enabled_repositories = optional(string, "all") selected_repository_ids = optional(set(number), []) allowed_actions = optional(string, "selected") github_owned_allowed = optional(bool, true) verified_allowed = optional(bool, true) patterns_allowed = optional(set(string), []) sha_pinning_required = optional(bool) })``` | `{}` | no |
| enabled | Set false to create nothing. Every output is then null. On an organisation this module already manages, false is refused at plan by design (prevent_destroy), because the provider's destroy writes fixed, looser values to the live organisation. To stop managing it, remove the module call and add removed blocks with destroy = false (README). | `bool` | `true` | no |
| features | Organisation features. Organisation and repository projects on (GitHub's own defaults); web commit sign-off off. web_commit_signoff_required asks for a Signed-off-by line on commits made in the web UI; it is not commit signature verification. | ```object({ organization_projects = optional(bool, true) repository_projects = optional(bool, true) web_commit_signoff_required = optional(bool, false) })``` | `{}` | no |
| member_privileges | What organisation members (not owners) may do. Defaults: base permission read on every repository; members may create private repositories but not public ones; no forking of private repositories; no GitHub Pages sites. create_internal_repositories applies to GitHub Enterprise Cloud organisations only; the provider does not send it for any other plan. | ```object({ default_repository_permission = optional(string, "read") create_repositories = optional(bool, true) create_public_repositories = optional(bool, false) create_private_repositories = optional(bool, true) create_internal_repositories = optional(bool, false) fork_private_repositories = optional(bool, false) create_pages = optional(bool, false) create_public_pages = optional(bool, false) create_private_pages = optional(bool, false) })``` | `{}` | no |
| new_repository_security | Security features turned on for repositories created after this is applied. Existing repositories keep their own settings; manage those per repository. Defaults: dependency graph, Dependabot alerts, Dependabot security updates, secret scanning and push protection on; Advanced Security off (paid). On private repositories, secret scanning and push protection need GitHub Secret Protection on the owner's plan: turn both off explicitly where the plan lacks it. | ```object({ dependency_graph = optional(bool, true) dependabot_alerts = optional(bool, true) dependabot_security_updates = optional(bool, true) secret_scanning = optional(bool, true) secret_scanning_push_protection = optional(bool, true) advanced_security = optional(bool, false) })``` | `{}` | no |
| profile | Public profile of the organisation: display name, description, public email, blog URL, company, location and Twitter username. Null leaves a field out. The provider never sends an empty value, so neither null nor "" clears a field that is set on GitHub; set every field GitHub already shows to its current value, or the plan shows a change on every run. | ```object({ display_name = optional(string) description = optional(string) email = optional(string) blog = optional(string) company = optional(string) location = optional(string) twitter_username = optional(string) })``` | `{}` | no |
| workflow_permissions | Default permissions of the GITHUB_TOKEN in every repository of the organisation. Defaults: read-only token, and workflows may not approve pull requests. A repository can still raise its own token's permissions in a workflow's permissions block. | ```object({ default_workflow_permissions = optional(string, "read") can_approve_pull_request_reviews = optional(bool, false) })``` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| organization | Login of the organisation the settings apply to: the github provider's owner. Null when the module is disabled. |
| organization_id | Numeric id of the organisation. Null when the module is disabled. |
<!-- END_TF_DOCS -->
