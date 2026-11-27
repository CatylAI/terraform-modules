# gcp/service-account

One service account, its project role bindings, and the bindings that let named principals act as
it. It never creates a key. It follows [the module standard](../../../docs/spec/module-standard.md).

```hcl
module "orders_api_sa" {
  source = "git::https://github.com/CatylAI/terraform-modules.git//modules/gcp/service-account?ref=gcp-service-account-v0.1.0"

  context    = local.context # tenant, environment, component, repo from the root
  name       = "api"         # account id: <tenant>-<environment>-<component>-api
  project_id = var.project_id

  project_roles = {
    aiplatform = { role = "roles/aiplatform.user" }
  }

  impersonation = {
    github-actions = {
      role    = "roles/iam.workloadIdentityUser"
      members = [var.github_principal_set] # from a Workload Identity Federation pool
    }
  }
}
```

## Defaults, and how to override them

| Setting | Default | Override (in the root's tfvars) |
|---|---|---|
| Keys | never created | none (invariant, MS-6.1). Sign in through impersonation or Workload Identity Federation |
| Project roles | none | `project_roles = { <name> = { role = "roles/..." } }`, granted to this account in `project_id`. Basic roles (`roles/owner`, `roles/editor`, `roles/viewer`) are rejected |
| Impersonation | nobody | `impersonation = { <name> = { role, members } }`. `role` is one of `roles/iam.serviceAccountTokenCreator`, `roles/iam.serviceAccountOpenIdTokenCreator`, `roles/iam.serviceAccountUser` or `roles/iam.workloadIdentityUser`. `allUsers` and `allAuthenticatedUsers` are rejected |
| Token creation | not granted | only through an explicit `impersonation` entry with `roles/iam.serviceAccountTokenCreator` |
| Deletion | `deletion_policy = "PREVENT"` | `deletion_protection = { enabled = false }` for scratch environments |
| Display name, description | unset | `display_name` (up to 100 characters), `description` (up to 256) |

Every binding is additive: one IAM member per grant, never an authoritative policy or binding. The
module adds what it is given and never removes a grant it did not create, so it is safe beside
grants made by other roots or by hand.

`role` in `impersonation` has no default. An entry names the right it grants, so a token creator
is always visible in the root's tfvars.

## Naming

The account id is `<prefix>-<name>`, where the prefix is `context.name_prefix` or
`<tenant>-<environment>-<component>`. Google limits account ids to 6-30 characters of lowercase
letters, digits and hyphens, starting with a letter and not ending with a hyphen. That is short,
and the computed id can exceed it: `acme-staging-payments-reconciler` is 32 characters. A
precondition fails the plan with a message saying what to change. Shorten `name` or
`context.component`, or set a shorter `context.name_prefix`. `name_override` is for adopting an
existing account only (below).

## No labels

Service accounts carry no labels in Google Cloud, so `module.context.labels` is not applied
anywhere in this module. The `context` input is still validated, and the account id still comes
from it. Find an account's owner by its id prefix, and put its purpose in `description`.

## Cost shape

None. Service accounts and IAM bindings are not billed. No input changes that.

## Adopting an existing service account

Set `name_override` to the existing account id, add a `moved` block (from a raw resource) or an
`import` block, and require a plan that shows no changes (ADR-0013). The id must still be 6-30
characters.

```hcl
moved {
  from = google_service_account.orders
  to   = module.orders_api_sa.google_service_account.this[0]
}
```

Existing grants on the account or in the project are left alone, because every binding the module
makes is additive. Bring a grant under the module by adding it to `project_roles` or
`impersonation` and importing the matching IAM member.

## Architecture Framework

| Pillar | Default | Trade-off |
|---|---|---|
| Security | No keys, ever; no basic roles; no public principals; nobody can impersonate the account and nobody can mint tokens for it until an explicit `impersonation` entry says so; impersonation roles limited to four | A role outside the four impersonation roles needs a direct IAM grant in the root |
| Reliability | `deletion_policy = "PREVENT"`, so a plan cannot delete an identity that other grants name; additive bindings cannot revoke grants made elsewhere | Teardown takes a tfvars change first. Additive bindings also mean a grant removed by hand elsewhere is not restored by this module |
| Cost optimization | Nothing billed | None |
| Operational excellence | Account id derived from context; one input shape across modules; a precondition explains an over-long id at plan time | No labels exist to filter on, so ownership is read from the id prefix |
| Performance | Not applicable; IAM has no capacity settings | None |
| Sustainability | Not applicable; no resources consume compute or storage | None |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.14, < 2.0 |
| google | >= 8.3, < 9.0 |

## Providers

| Name | Version |
| ---- | ------- |
| google | >= 8.3, < 9.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| context | ../../_internal/context | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [google_project_iam_member.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.impersonation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| context | Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3). | ```object({ tenant = string environment = string component = string repo = string labels = optional(map(string), {}) allowed_environments = optional(list(string)) name_prefix = optional(string) })``` | n/a | yes |
| name | Logical name of this service account, unique within the component. Kebab-case. The account id is <prefix>-<name>, where prefix is context.name_prefix or <tenant>-<environment>-<component>; it must come to 6-30 characters. | `string` | n/a | yes |
| project_id | Project that owns the service account and receives its project role bindings. | `string` | n/a | yes |
| deletion_protection | When enabled, Terraform refuses to destroy the service account (deletion_policy PREVENT). A deleted account breaks every grant that names it, and a recreated one gets a new unique id. | ```object({ enabled = optional(bool, true) })``` | `{}` | no |
| description | What the account is for. Null leaves it unset. At most 256 characters. | `string` | `null` | no |
| display_name | Human-readable name shown in the console. Null leaves it unset. At most 100 characters. | `string` | `null` | no |
| enabled | Set false to create nothing. Every output is then null. | `bool` | `true` | no |
| impersonation | Principals allowed to act as this service account, keyed by a stable binding name. role must be one of roles/iam.serviceAccountTokenCreator (mint access and ID tokens), roles/iam.serviceAccountOpenIdTokenCreator (ID tokens only), roles/iam.serviceAccountUser (attach the account to a workload) or roles/iam.workloadIdentityUser (Workload Identity Federation or GKE sign-in). Nothing is granted by default, so token creation exists only through an explicit entry. Members are a map keyed by a stable member name (e.g. { ci = "principalSet://..." }), so a principal created in the same apply can be granted; each is an additive binding. Public principals are rejected. | ```map(object({ role = string members = map(string) }))``` | `{}` | no |
| name_override | Verbatim account id, only for adopting a service account that predates the naming convention (ADR-0013). Leave null for new accounts. It must still be 6-30 characters. | `string` | `null` | no |
| project_roles | Project roles granted to this service account in project_id, keyed by a stable binding name. Each binding is additive (one IAM member), so the module never removes a grant it did not create. Basic roles are rejected. | ```map(object({ role = string }))``` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| email | Email address of the service account. Null when the module is disabled. |
| member | IAM member string for the service account, serviceAccount:<email>, for granting it roles elsewhere. Null when the module is disabled. |
| name | Full resource name of the service account, projects/<project>/serviceAccounts/<email>. Null when the module is disabled. |
| unique_id | Stable numeric unique id of the service account. Null when the module is disabled. |
<!-- END_TF_DOCS -->
