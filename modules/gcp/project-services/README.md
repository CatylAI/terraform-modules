# gcp/project-services

Enables Google APIs on a project that already exists, one enablement per entry of a map. Removing
an entry leaves the API enabled, so a tfvars edit cannot switch off an API that something still
calls. It follows [the module standard](../../../docs/spec/module-standard.md).

```hcl
module "services" {
  source = "git::https://github.com/CatylAI/terraform-modules.git//modules/gcp/project-services?ref=gcp-project-services-v0.1.0"

  context    = local.context # tenant, environment, component, repo from the root
  name       = "apis"        # logical name of this set; API enablements have no name of their own
  project_id = var.project_id
  services = {
    iam            = { service = "iam.googleapis.com" }
    iamcredentials = { service = "iamcredentials.googleapis.com" }
  }
}
```

## Defaults, and how to override them

| Setting | Default | Override (in the root's tfvars) |
|---|---|---|
| Removing an entry | the API stays enabled; Terraform only stops managing it (`disable_on_destroy = false`, against the provider's own default of `true`) | `disable_on_destroy = true` on that entry |
| APIs that depend on a disabled one | never disabled with it (`disable_dependent_services = false`); the disable fails while a dependent API is enabled | `disable_dependent_services = true` on that entry, accepted only with `disable_on_destroy = true` |
| Service names | must be full API names ending in `.googleapis.com`, each named once | none |

To retire an API, set `disable_on_destroy = true` on its entry and apply, then remove the entry and
apply again. Removing the entry in the same change as the override does not work: Terraform
destroys with the setting already in state, which is still `false`.

Make a resource wait for its API by referencing the output, for example
`depends_on = [module.services]` or an expression that reads `module.services.services["iam"]`.

## Cost shape

None. Enabling an API is free; you pay for what you then use through it, which this module does not
create. No input changes the cost.

## Adopting enabled APIs

APIs that are already enabled need no import: enabling an enabled API is a no-op, so the first
apply only records them in state. To move from a raw resource, use a `moved` block:

```hcl
moved {
  from = google_project_service.iam
  to   = module.services.google_project_service.this["iam"]
}
```

The module offers no `name_override`: API enablements have no computed name to override.

## Architecture Framework

| Pillar | Default | Trade-off |
|---|---|---|
| Security | Only the listed APIs are enabled; the service-name validation rejects typos and look-alike domains | None |
| Reliability | Removing an entry never disables an API, and a disable never cascades to dependent APIs unless an entry asks for both | APIs nobody uses any more stay enabled until someone opts that entry into `disable_on_destroy` |
| Cost optimization | No cost of its own | None |
| Operational excellence | One map, keyed by stable names, holds the project's API list; the context call validates the shared inputs | None |
| Performance | Not applicable: enablement has no runtime path | None |
| Sustainability | Not applicable | None |

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
| [google_project_service.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| context | Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3). | ```object({ tenant = string environment = string component = string repo = string labels = optional(map(string), {}) allowed_environments = optional(list(string)) name_prefix = optional(string) })``` | n/a | yes |
| name | Logical name of this set of services, unique within the component. Kebab-case. API enablements have no name of their own, so it identifies the module instance only. | `string` | n/a | yes |
| project_id | Existing project in which to enable the APIs. | `string` | n/a | yes |
| services | APIs to enable, keyed by a stable name. service is the full API name (e.g. iam.googleapis.com). Removing an entry stops managing the API and leaves it enabled. disable_on_destroy = true makes removal disable the API; disable_dependent_services = true (only with disable_on_destroy) also disables every enabled API that depends on it. | ```map(object({ service = string disable_on_destroy = optional(bool, false) disable_dependent_services = optional(bool, false) }))``` | n/a | yes |
| enabled | Set false to create nothing. The services output is then empty. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| services | Enabled API names keyed like var.services. Empty when the module is disabled. Reference it to make a resource wait for its API. |
<!-- END_TF_DOCS -->
