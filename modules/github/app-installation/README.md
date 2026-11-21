# github/app-installation

Attaches an existing GitHub App installation to a set of repositories, one additive attachment per
repository. It follows [the module standard](../../../docs/spec/module-standard.md).

```hcl
module "release_app" {
  source = "git::https://github.com/CatylAI/terraform-modules.git//modules/github/app-installation?ref=github-app-installation-v0.1.0"

  context         = local.context                      # validated; nothing is derived from it
  name            = "release-app"                      # identifies the call; not sent to GitHub
  installation_id = 12345678                           # required, a positive whole number
  repositories    = ["orders-service", "billing-api"]  # names verbatim, without the owner
}
```

The module does not create or install the App. Install it once on the organisation (or account)
the provider's `owner` names, with access to **Only select repositories**, and read the
installation id from the end of the installation's settings URL
(`.../settings/installations/<id>`). The module then manages which of the selected repositories it
owns.

Repository names are used verbatim, with no prefix and no labels (ADR-0016), and need not be
kebab-case (`.github` and `Legacy_Service.v2` are accepted). `name` is only the kebab-case id of
the module call.

## Additive, not authoritative

Each repository is its own `github_app_installation_repository`, keyed by its name. The module
adds the repositories it lists and, on destroy or removal from the set, removes only those.
Repositories attached in the GitHub UI or by another root are left alone and never appear in the
plan.

The provider's plural resource, `github_app_installation_repositories`, is not used: its
`selected_repositories` is the installation's whole repository list, so applying it would remove
the App from every repository not listed. With the additive form, two roots can each attach their
own repositories to one installation.

## Defaults, and how to override them

| Setting | Default | Override (in the root's tfvars) |
|---|---|---|
| Installation id | none: required | `installation_id = <id>`; `null` is accepted only with `enabled = false` |
| Repositories | none: required, at least one while enabled | `repositories = ["<name>", ...]` |
| Ownership of the installation's repository list | additive: only the listed repositories are managed | none (an authoritative list is deliberately not offered) |

A root whose installation is optional drives both from one variable:

```hcl
enabled         = var.release_app_installation_id != null
installation_id = var.release_app_installation_id
```

### Authentication

The GitHub endpoints behind this resource live under `/user/installations/...`: they act as a
user, not as an App. GitHub documents a classic personal access token with the `repo` scope, and
the user must have admin access to every listed repository (an organisation owner has it on all of
them). An App installation token cannot call them, so a root authenticated as a GitHub App fails
here even when every other resource applies. Keep the token in the environment (`GITHUB_TOKEN`),
never in code or tfvars. The module takes no token input (MS-6.2).

### Removing repositories, and destroy

GitHub refuses (422) to remove a repository from an installation set to **All repositories**, and
to remove the last repository an installation can reach in the organisation. Install the App with
**Only select repositories**. Destroying the module, or emptying it with `enabled = false`, fails
when its repositories are the installation's only ones: uninstall the App in the GitHub UI instead,
then drop the module's resources from state with a `removed` block
(`lifecycle { destroy = false }`).

## Cost shape

Nothing is billed: attaching a repository to an App installation is free on every GitHub plan, and
this module reserves no capacity. Any cost belongs to the App itself (for example a Marketplace
plan), which this module does not install or change.

## Adopting existing attachments

An attachment imports as `<installation_id>:<repository>`. From a raw resource in a root, a
`moved` block adopts it with no change to GitHub; set `installation_id` and `repositories` to the
values the raw resource had, and require a plan that shows no changes.

```hcl
moved {
  from = github_app_installation_repository.release_app[0]
  to   = module.release_app.github_app_installation_repository.this["orders-service"]
}

# Or, for an attachment that was never in state:
import {
  to = module.release_app.github_app_installation_repository.this["orders-service"]
  id = "12345678:orders-service"
}
```

Adoption from `github_app_installation_repositories` (plural) is a `removed` block with
`lifecycle { destroy = false }` for the plural resource, plus one `import` per repository, so the
installation's repository list is never rewritten in between.

## Architecture Framework

| Pillar | Default | Trade-off |
|---|---|---|
| Security | The App reaches only the repositories listed, one attachment each; no token input; repository names validated so an owner-qualified name cannot slip through | The endpoints need a user token with admin on each repository, a broader credential than the App token most roots use; keep it out of unattended runs or leave the installation to the UI |
| Reliability | Additive attachments: repositories attached elsewhere are never removed, and adding or removing one repository never touches the others | Destroy removes the App's access to the listed repositories (re-applying restores it, and no repository data is lost); GitHub refuses to remove an installation's last repository, so destroy fails there |
| Cost optimization | Nothing billed | None |
| Operational excellence | One input shape across modules; repositories keyed by name, so the plan names the repository that changes | Repositories attached outside Terraform are invisible to this module, so the installation's full list lives only in GitHub |
| Performance | None: an installation's repository list has no performance dimension | None |
| Sustainability | None: no resources run or store data | None |

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
| [github_app_installation_repository.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/app_installation_repository) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| context | Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3). Validated, but not applied: GitHub resources carry no labels and no prefix (ADR-0016). | ```object({ tenant = string environment = string component = string repo = string labels = optional(map(string), {}) allowed_environments = optional(list(string)) name_prefix = optional(string) })``` | n/a | yes |
| installation_id | Numeric id of the GitHub App installation, the number at the end of the installation's settings URL (.../settings/installations/<id>). The App must already be installed on the provider's owner with access to selected repositories. Required; null is accepted only when enabled = false, so a root can drive both from one optional variable. | `number` | n/a | yes |
| name | Logical name of this instance, unique within the component. Kebab-case. It identifies the module call (for example release-app) and is not sent to GitHub: repositories are named by repositories, verbatim (ADR-0016). | `string` | n/a | yes |
| repositories | Names of the repositories to attach to the installation, without the owner (orders-service, not acme/orders-service). The owner is the provider's. Each name is a stable for_each key, so adding or removing one never touches the others. Additive: repositories attached outside this module are left alone. | `set(string)` | n/a | yes |
| enabled | Set false to create nothing. Every output is then null. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| repositories | Names of the repositories this module attaches to the installation. Repositories attached outside this module are not listed. Null when the module is disabled. |
<!-- END_TF_DOCS -->
