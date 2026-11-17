# _internal/context

Validates `context`, computes the resource name and builds the label map for every module in
this repository (module-standard MS-3, ADR-0008). Consumers never source it directly; each module
calls it by relative path, `../../_internal/context`.

A change here changes every module's behavior. Refresh every module's `.context-digest` in the
same change (`python3 scripts/check_invariants.py --write-digests`) so release-please bumps them
all (ADR-0012).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.14, < 2.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| context | Who and where, supplied by the calling root (module-standard MS-3):   tenant                organisation or business unit, kebab-case   environment           one of allowed_environments   component             the root's component, kebab-case   repo                  repository holding the root   labels                extra labels; reserved keys are rejected   allowed_environments  override of the environment vocabulary (default: contracts/environments.v1.json)   name_prefix           override of the computed <tenant>-<environment>-<component> prefix | ```object({ tenant = string environment = string component = string repo = string labels = optional(map(string), {}) allowed_environments = optional(list(string)) name_prefix = optional(string) })``` | n/a | yes |
| module | Id of the calling module, <provider>-<name> (e.g. gcp-gcs-bucket). Becomes the `module` label. | `string` | n/a | yes |
| name | Logical name of the instance, unique within the component. Kebab-case. | `string` | n/a | yes |
| name_override | Verbatim name for adopting a resource that predates the naming convention (ADR-0013). Leave null for new resources. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| labels | Caller labels merged with the reserved keys, folded to GCP label rules. Reserved keys win. |
| name | Resource name: name_override when set, otherwise <tenant>-<environment>-<component>-<name>. |
| name_prefix | context.name_prefix, or <tenant>-<environment>-<component>, for modules that derive several names. |
<!-- END_TF_DOCS -->
