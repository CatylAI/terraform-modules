# github/org-ruleset

One organisation ruleset on branches or tags: which repositories and refs it covers, who may
bypass it, and its rules, with deletion and force pushes blocked by default. It follows
[the module standard](../../../docs/spec/module-standard.md).

```hcl
module "protect_default_branch" {
  source = "git::https://github.com/CatylAI/terraform-modules.git//modules/github/org-ruleset?ref=github-org-ruleset-v0.1.0"

  context = local.context          # validated; the name and rules do not depend on it
  name    = "protect-default-branch" # the ruleset name, verbatim
  target  = "branch"               # required: branch or tag

  conditions = {
    repository_name = { include = ["~ALL"] } # required: which repositories
  }

  rules = {
    pull_request = {} # one approval, code-owner review, stale approvals dismissed
  }
}
```

One module call manages one ruleset. Call it once per ruleset. The ruleset is named `var.name`
exactly: no prefix, no labels (ADR-0016). `name` is kebab-case, because `_internal/context`
validates it as the instance id. For a ruleset whose name is not kebab-case (`Services: main`),
set `ruleset_name`: the ruleset is then named `ruleset_name` verbatim, and `name` stays any
kebab-case id.

## Defaults, and how to override them

| Setting | Default | Override (in the root's tfvars) |
|---|---|---|
| Target | none: required | `target = "branch" \| "tag"` |
| Repositories | none: required | `conditions = { repository_name = { include = ["~ALL"], exclude = ["sandbox-*"] } }` |
| Refs | the default branch (`~DEFAULT_BRANCH`), excluding nothing | `conditions = { ref_name = { include = ["refs/tags/v*"] }, ... }` |
| Enforcement | `active` | `enforcement = "evaluate"` (report only, GitHub Enterprise) or `"disabled"` |
| Deletion | blocked | `rules = { deletion = false }` |
| Force pushes | blocked (`non_fast_forward`) | `rules = { non_fast_forward = false }` |
| Creation, update, linear history, signed commits | off | `rules = { required_linear_history = true, ... }` |
| Pull request before merging | absent | `rules = { pull_request = {} }`: 1 approval, code-owner review, stale approvals dismissed; override any attribute |
| Required status checks | none | `rules = { required_status_checks = { "<check context>" = { integration_id = <app id> } } }`; read the warning below first |
| Bypass | nobody | `bypass_actors = { <stable name> = { actor_type, actor_id, bypass_mode } }` |

Each group is an object with optional attributes. Set one attribute and the rest keep their
defaults. A ruleset must turn on at least one rule; one with none protects nothing and is
rejected.

The deletion and force-push blocks apply to tags as well: on a tag ruleset they stop a release tag
from being deleted or moved.

### Required status checks stall bot pull requests

The required check list is empty by default, on purpose. A pull request opened with
`GITHUB_TOKEN` (release-please, or any other workflow that opens pull requests) starts no
workflow run, so a required check **never reports** on it and the pull request
cannot merge. An organisation ruleset reaches many repositories at once, so check each one before
you require a check: either make sure the check reports on every pull request there (open bot
pull requests with a GitHub App token instead), or give that bot a bypass actor, or leave the
repository out of `conditions`. Pin `integration_id` to the app that must report the check (15368
is GitHub Actions), so another app cannot satisfy it.

### Bypass actors

`bypass_actors` is a map keyed by a name you choose, so adding or removing one actor never
reorders the rest. `actor_id` is the team id, the GitHub App (integration) id or the repository
role id (for example 5 for the built-in admin role). `OrganizationAdmin`, `EnterpriseOwner` and
`DeployKey` have no id: leave `actor_id` unset for them, because GitHub ignores it and the plan
would never settle. `bypass_mode` defaults to `pull_request`, so the actor can bypass only by
merging a pull request. Every bypass is recorded in the organisation's audit log.

### Repository rulesets are not supported

GitHub also offers organisation rulesets with the `repository` target, whose rules block deleting,
transferring or changing the visibility of a repository (`repository_delete`,
`repository_transfer`, `repository_visibility`). The github provider's
`github_organization_ruleset` (through 6.13.0) accepts only the `branch`, `tag` and `push` targets
and has no such rules, so this module cannot manage them. Push rulesets (file path, size and
extension rules) are out of this module's scope. `target` rejects both.

## Cost shape

Nothing is billed by this module. Organisation rulesets are a feature of the organisation's GitHub
plan: on private and internal repositories they need GitHub Team or higher, `evaluate`
enforcement needs GitHub Enterprise. Required status checks add no cost of their own; the
workflows that report them are billed to the owner by use, as they are without the ruleset. The
input that changes cost is `enforcement` (`evaluate` needs Enterprise).

## Adopting an existing ruleset

The name is used verbatim, so adoption is an `import` with no rename. Set every input to the
ruleset's current value (read it with `gh api /orgs/<org>/rulesets/<id>`), then require a plan
that shows no changes:

- `name`: the ruleset's exact name when it is kebab-case. Otherwise any kebab-case id, with
  `ruleset_name` set to the exact name
- `target` and `enforcement`
- `conditions`, with patterns in the order GitHub returns them
- `bypass_actors`, one entry per actor
- `rules`: every rule the live ruleset has, and `false` for `deletion` and `non_fast_forward` where
  it lacks them (both default to `true`). A live pull request rule needs `pull_request` with every
  attribute matched, because the defaults inside it are not GitHub's

```hcl
import {
  to = module.protect_default_branch.github_organization_ruleset.this[0]
  id = "<ruleset id>" # the numeric id, from the URL or the API
}
```

A ruleset managed elsewhere in the same state (for example as a REST resource) moves with an
`import` here plus a `removed { from = <old address> lifecycle { destroy = false } }` block for the
old resource, so neither step changes the ruleset on GitHub. `moved` cannot cross resource types.

## Architecture Framework

| Pillar | Default | Trade-off |
|---|---|---|
| Security | Enforcement active; deletion and force pushes blocked; nobody bypasses; ID-less actors cannot carry an id GitHub would ignore; required checks can be pinned to one app | The pull request rule is absent until a root adds it, because an organisation-wide review requirement can block repositories with one maintainer |
| Reliability | Branches and tags under the ruleset cannot be deleted or rewritten, so history survives a mistaken push | A blocked force push needs a bypass actor or a temporary rule change to repair a bad commit |
| Cost optimization | Nothing paid is required by the defaults; required checks are off, so no Actions minutes are spent by this module | `evaluate` mode and private-repository rulesets need a paid plan |
| Operational excellence | One ruleset per call; bypass actors and required checks keyed by stable names, so a change is in place; patterns kept in order so an adopted ruleset plans clean | No required checks by default means CI results are advisory until a root lists them |
| Performance | None: rulesets have no performance dimension | None |
| Sustainability | None | None |

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
| [github_organization_ruleset.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/organization_ruleset) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| conditions | Which repositories and refs the ruleset applies to. Required: an organisation ruleset's reach is the caller's decision. repository_name patterns match repository names (~ALL matches every repository); ref_name patterns match refs (~DEFAULT_BRANCH, ~ALL, refs/heads/<pattern>, refs/tags/<pattern>) and default to the default branch. Lists keep their order, as GitHub stores them. | ```object({ ref_name = optional(object({ include = optional(list(string), ["~DEFAULT_BRANCH"]) exclude = optional(list(string), []) }), {}) repository_name = object({ include = list(string) exclude = optional(list(string), []) }) })``` | n/a | yes |
| context | Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3). Validated, but GitHub carries no labels and the ruleset name ignores it (ADR-0016). | ```object({ tenant = string environment = string component = string repo = string labels = optional(map(string), {}) allowed_environments = optional(list(string)) name_prefix = optional(string) })``` | n/a | yes |
| name | Logical name of this instance, kebab-case. It is also the ruleset name, verbatim with no prefix (ADR-0016), unless ruleset_name is set. | `string` | n/a | yes |
| target | What the ruleset protects: branch or tag. Required. The github provider does not support the repository target (repository deletion, transfer and visibility rules) or, in this module, push rulesets. | `string` | n/a | yes |
| bypass_actors | Actors who may bypass the ruleset, keyed by a stable name. actor_id is the team, app (integration) or repository role id; leave it unset for OrganizationAdmin, EnterpriseOwner and DeployKey, which have none. bypass_mode: always, pull_request (only by merging a pull request) or exempt. Nobody bypasses by default. | ```map(object({ actor_type = string actor_id = optional(number) bypass_mode = optional(string, "pull_request") }))``` | `{}` | no |
| enabled | Set false to create nothing. Every output is then null. | `bool` | `true` | no |
| enforcement | Enforcement level: active (enforced), evaluate (report only; GitHub Enterprise) or disabled. | `string` | `"active"` | no |
| rules | The ruleset's rules. Deletion and force pushes (non_fast_forward) are blocked by default; the rest are off. pull_request is absent by default: pull_request = {} requires a pull request with one approval and code-owner review, dismissing stale approvals, and enabled = false removes it.  required_status_checks is keyed by the check context, for example "ci / test". A required check never reports on a pull request opened with GITHUB_TOKEN (release-please and other bots), so requiring one stalls those pull requests. Pin integration_id to the app that must report the check. | ```object({ deletion = optional(bool, true) non_fast_forward = optional(bool, true) creation = optional(bool, false) update = optional(bool, false) required_linear_history = optional(bool, false) required_signatures = optional(bool, false) pull_request = optional(object({ enabled = optional(bool, true) required_approving_review_count = optional(number, 1) require_code_owner_review = optional(bool, true) dismiss_stale_reviews_on_push = optional(bool, true) require_last_push_approval = optional(bool, false) required_review_thread_resolution = optional(bool, false) })) required_status_checks = optional(map(object({ integration_id = optional(number) })), {}) strict_required_status_checks = optional(bool, false) })``` | `{}` | no |
| ruleset_name | Ruleset name when it is not kebab-case, for example one with capitals, spaces or a colon, so an existing ruleset is adopted by import with no rename. At most 100 characters. Null uses name. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| name | The ruleset's name on GitHub. Null when the module is disabled. |
| node_id | GraphQL node id of the ruleset. Null when the module is disabled. |
| ruleset_id | GitHub's numeric id of the ruleset, the id an import uses. Null when the module is disabled. |
<!-- END_TF_DOCS -->
