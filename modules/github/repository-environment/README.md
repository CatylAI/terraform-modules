# github/repository-environment

One deployment environment on an existing repository, with a deployment branch policy, optional
required reviewers and environment variables. The environment is never left open: without
reviewers, only protected branches may deploy. It follows
[the module standard](../../../docs/spec/module-standard.md).

```hcl
module "production" {
  source = "git::https://github.com/CatylAI/terraform-modules.git//modules/github/repository-environment?ref=github-repository-environment-v0.1.0"

  context          = local.context      # tenant, environment, component, repo from the root
  name             = "orders-production" # this module call, unique within the component
  repository       = "orders-service"
  environment_name = "production"        # the GitHub environment, used verbatim
}
```

## Names: `name` and `environment_name`

`environment_name` is the GitHub environment's own name, the value a workflow puts in
`environment:`. It is used verbatim and never prefixed (ADR-0016). It is not
`context.environment`: a `prod` root can manage a `staging` environment on some repository, and
the module never reads `context.environment` (MS-3.5).

`name` is the standard's logical instance name. It identifies the module call within the
component and is validated as kebab-case, but it is not sent to GitHub. The two are separate
because:

- One component often manages the same environment on several repositories (`production` on
  `orders-service` and on `storefront`). Those calls need distinct `name`s but the same
  `environment_name`.
- GitHub environment names may hold capitals and spaces (`Production EU`), which a kebab-case
  `name` can't. Adopting an existing environment needs its exact name.

## Defaults, and how to override them

| Setting | Default | Override (in the root's tfvars) |
|---|---|---|
| Deployment refs | protected branches only | `deployment_branch_policy = { protected_branches = false, custom_patterns = { <key> = { branch_pattern = "main" } \| { tag_pattern = "v*" } } }`, or no patterns for any ref. Both need reviewers |
| Required reviewers | none | `reviewers = { users = [<id>], teams = [<id>] }`, at most six in total |
| Self-review | blocked whenever reviewers are set | none (invariant) |
| Admin bypass | off | `admin_bypass = { enabled = true }` |
| Variables | none | `variables = { DEPLOY_REGION = "us-east1" }` |
| Secrets | never | none (invariant, MS-6.2): set environment secrets out of band |
| Wait timer | none | not offered |

The validation rules:

- **No reviewers.** `deployment_branch_policy.protected_branches` must stay `true`. An open or
  pattern-based policy with nobody to approve would let anyone who can push a matching branch
  deploy.
- **Policies.** GitHub takes protected branches or custom patterns, not both. Each pattern sets
  exactly one of `branch_pattern` or `tag_pattern`.
- **Reviewers.** They are numeric ids, at most six users and teams in total. Resolve logins and
  slugs with `data "github_user"` and `data "github_team"`, and wrap the `id` in `tonumber()`.
- **Variable names.** Upper case, letters, digits and `_`. Not starting with a digit or
  `GITHUB_`, at most 100. A name containing `PASSWORD`, `SECRET`, `TOKEN` or `PRIVATE_KEY` is
  rejected. Variable values are plain text in state and plans.

### Reviewers and your GitHub plan

On GitHub Free, Pro and Team, required reviewers (and wait timers) work only in **public**
repositories. On a private repository there, leave `reviewers` empty and approve at the pull
request instead:

- `main` requires code-owner review, so whoever opens a change can't merge it alone.
- The environment accepts only protected branches, so nothing reaches it without that merge.

`examples/minimal` is this setup. `examples/complete` shows reviewers, for a public repository
or Enterprise.

"Protected branches only" means branches with branch protection rules. GitHub documents that when
no branch in the repository is protected, every branch can deploy. Make sure the branch you deploy
from is protected (for example with `github/repository`'s default-branch rules) before relying on
this policy.

## Cost shape

None. Environments, deployment branch policies, reviewers and variables are not billed. Required
reviewers on a private repository need GitHub Enterprise; that is a plan choice, not something
this module reserves.

## Adopting an existing environment

Set `environment_name` to the environment's exact name, match the live settings in the inputs,
and import. Require a plan with no changes. The provider's import ids are:

- environment: `<repository>:<environment>`
- deployment policy: `<repository>:<environment>:<policy id>`
- environment variable: `<repository>:<environment>:<variable name>`

```hcl
import {
  to = module.production.github_repository_environment.this[0]
  id = "orders-service:production"
}

import {
  to = module.production.github_actions_environment_variable.this["DEPLOY_REGION"]
  id = "orders-service:production:DEPLOY_REGION"
}
```

The module sends `prevent_self_review = false` when there are no reviewers, which is what GitHub
reports for an environment without them. A live wait timer has no input here, so it shows as a
change to remove.

## Architecture Framework

| Pillar | Default | Trade-off |
|---|---|---|
| Security | Protected-branch-only deployments; self-review blocked with reviewers; admin bypass off; no environment can be both reviewer-less and open; no secret inputs | Admin bypass off means an administrator can't hot-fix past the policy; that path is a reviewed change to `admin_bypass` |
| Reliability | Deployments come only from refs that passed the branch's required checks | None |
| Cost optimization | Nothing billed | Required reviewers on private repositories need Enterprise; the module works without them |
| Operational excellence | One input shape across modules; the environment name is verbatim, so workflow references never change | None |
| Performance | None: no wait timer delays a job | None |
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
| [github_actions_environment_variable.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_environment_variable) | resource |
| [github_repository_environment.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_environment) | resource |
| [github_repository_environment_deployment_policy.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_environment_deployment_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| context | Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3). Validated, but not applied: GitHub resources carry no labels and no prefix (ADR-0016). | ```object({ tenant = string environment = string component = string repo = string labels = optional(map(string), {}) allowed_environments = optional(list(string)) name_prefix = optional(string) })``` | n/a | yes |
| environment_name | The GitHub environment's own name, used verbatim (for example production). Workflows reference it in `environment:`. It is unrelated to the environment in context, which no module reads (MS-3.5, ADR-0016). GitHub treats environment names case-insensitively. | `string` | n/a | yes |
| name | Logical name of this instance, unique within the component. Kebab-case. It identifies the module call (for example orders-production) and is not sent to GitHub; the environment is named by environment_name. | `string` | n/a | yes |
| repository | Name of the existing repository that owns the environment, without the owner (orders-service, not acme/orders-service). The owner is the provider's. | `string` | n/a | yes |
| admin_bypass | Whether repository administrators can bypass the environment's protection rules. Off by default. | ```object({ enabled = optional(bool, false) })``` | `{}` | no |
| deployment_branch_policy | Which refs may deploy. protected_branches = true (the default) allows only branches with branch protection. Set protected_branches = false with custom_patterns (keyed by a stable name, each one branch_pattern or tag_pattern) to allow only matching refs, or with no patterns to allow any ref. Without reviewers, only the protected-branch policy is accepted, so the environment is never left open. | ```object({ protected_branches = optional(bool, true) custom_patterns = optional(map(object({ branch_pattern = optional(string) tag_pattern = optional(string) })), {}) })``` | `{}` | no |
| enabled | Set false to create nothing. Every output is then null. | `bool` | `true` | no |
| reviewers | Required reviewers, as numeric GitHub user and team ids. One approval releases the job, and the person who triggered it cannot approve it (self-review is always blocked when reviewers are set). At most six users and teams in total. On GitHub Free, Pro and Team, required reviewers work only in public repositories; leave this empty on a private repository and rely on a protected-branch-only policy, approved at the pull request. | ```object({ users = optional(set(number), []) teams = optional(set(number), []) })``` | `{}` | no |
| variables | Environment variables (vars context), keyed by variable name. Plain configuration only: values are stored in clear in state and shown in plans. Secrets are never passed here; set environment secrets out of band (MS-6.2). Names are upper case, letters, digits and '_', not starting with a digit or GITHUB_; at most 100 per environment. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| environment_name | The environment's name, for a workflow's `environment:` key. Null when the module is disabled. |
<!-- END_TF_DOCS -->
