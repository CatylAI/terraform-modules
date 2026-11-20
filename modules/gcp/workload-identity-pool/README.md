# gcp/workload-identity-pool

A workload identity pool and its OIDC providers, so a GitHub Actions workflow or a Kubernetes
workload signs in to Google Cloud with a short-lived token and no stored key. It follows
[the module standard](../../../docs/spec/module-standard.md).

```hcl
module "wif" {
  source = "git::https://github.com/CatylAI/terraform-modules.git//modules/gcp/workload-identity-pool?ref=gcp-workload-identity-pool-v0.1.0"

  context    = local.context # tenant, environment, component, repo from the root
  name       = "ci"          # pool id: <tenant>-<environment>-<component>-ci
  project_id = var.project_id

  oidc_providers = {
    github = {
      issuer_uri = "https://token.actions.githubusercontent.com"
      attribute_mapping = {
        "google.subject"                = "assertion.sub"
        "attribute.repository"          = "assertion.repository"
        "attribute.repository_owner_id" = "assertion.repository_owner_id"
      }
      attribute_condition = "assertion.repository_owner_id == '123456789'"
    }
  }
}
```

## Providers

`oidc_providers` is a map keyed by provider id. The key becomes the provider's id inside the pool,
so it is stable and human-chosen (MS-2.6). One pool serves several issuers. Two common shapes:

| Issuer | `issuer_uri` | Typical mapping | Typical condition |
|---|---|---|---|
| GitHub Actions | `https://token.actions.githubusercontent.com` | `google.subject`, `attribute.repository`, `attribute.repository_owner_id` | `assertion.repository_owner_id == '<owner id>'` |
| Kubernetes or k3s | the cluster's service-account issuer | `google.subject`, `attribute.namespace`, `attribute.service_account` | `assertion['kubernetes.io']['namespace'] == '<namespace>'` |

A cluster whose issuer Google cannot reach (a private API server) sets `jwks_json` to the
cluster's public keys (`kubectl get --raw /openid/v1/jwks`). It is public key material, not a
secret.

## Defaults and rules

| Setting | Default | Override (in the root's tfvars) |
|---|---|---|
| Attribute condition | none: required and non-empty | none (invariant). A provider without a condition trusts every subject on its issuer |
| GitHub owner guard | on for the GitHub Actions issuer | none (invariant). The condition must reference `assertion.repository_owner_id` and the mapping must map `attribute.repository_owner_id` |
| Issuer | required | must be `https://`, with no query or fragment |
| `google.subject` mapping | required | none; the API requires it for OIDC providers |
| Allowed audiences | empty: the token audience must be the provider's own resource name | `allowed_audiences = ["..."]`, at most 10 |
| Provider state | enabled | `disabled = true` stops new token exchanges without deleting the provider |
| Pool deletion | literal `prevent_destroy = true` and `deletion_policy = "PREVENT"` | none (MS-5.4, ADR-0011) |

The GitHub guard applies to `https://token.actions.githubusercontent.com` and to any enterprise
issuer under it. It pins trust to the owner's numeric id, which survives a rename; an owner name
can be released and claimed by someone else. The guard is a textual check: it proves the condition
names the owner id, not that the expression is correct. Find the id with
`gh api orgs/<org> --jq .id` (or `users/<user>`).

## Outputs for CI and IAM

`provider_names` gives each provider's full resource name, the value a CI sign-in step takes as
`workload_identity_provider`:

```text
projects/<project-number>/locations/global/workloadIdentityPools/<pool-id>/providers/<key>
```

`principal_sets` gives one IAM member prefix per custom attribute (`attribute.<name>`) mapped by
any provider, keyed by `<name>`. Attributes are pool-wide, so the map is the union over every
provider. Each value ends in `/`; append the attribute's value to get a member:

```text
principalSet://iam.googleapis.com/projects/<project-number>/locations/global/workloadIdentityPools/<pool-id>/attribute.<name>/
```

```hcl
resource "google_service_account_iam_member" "deployer" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "${module.wif.principal_sets["repository"]}acme/app"
}
```

`google.*` mappings get no entry. A single subject is
`principal://iam.googleapis.com/<pool_name>/subject/<value>`.

## Cost shape

None. Workload identity pools, providers and token exchange are not billed. No input changes that.

## Adopting an existing pool

Set `name_override` to the existing pool id, key each existing provider by its current id, add
`import` blocks (or `moved` blocks from raw resources), and require a plan that shows no changes
(ADR-0013).

```hcl
moved {
  from = google_iam_workload_identity_pool.github
  to   = module.wif.google_iam_workload_identity_pool.this[0]
}
```

## Removing a pool

The pool is never torn down per environment. A deleted pool's id stays reserved for about 30
days, and every IAM binding on its principals stops matching. Retire one by removing it from state
(`terraform state rm`) and deleting it outside Terraform on purpose. Providers carry no lock:
removing one from the map deletes it, so revoking trust is never blocked.

## Architecture Framework

| Pillar | Default | Trade-off |
|---|---|---|
| Security | Short-lived federated tokens instead of keys; a required, non-empty condition per provider; GitHub trust pinned to the immutable owner id; https issuers only | Removing a provider is unprotected, on purpose, so trust can always be revoked |
| Reliability | The pool is locked twice: literal `prevent_destroy` and `deletion_policy = "PREVENT"` in state | Teardown takes a deliberate `terraform state rm`, so scratch environments cannot drop the pool with a plain destroy |
| Cost optimization | Nothing is billed | None |
| Operational excellence | Pool id from context; providers keyed by stable ids; outputs shaped for CI and IAM bindings | Pools have no labels, so the context labels are not applied |
| Performance | Token exchange is served by Google's STS; nothing to size | None |
| Sustainability | No resources run or store data | None |

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
| [google_iam_workload_identity_pool.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| context | Who and where, supplied by the calling root: tenant, environment, component, repo, optional labels, allowed_environments and name_prefix (module-standard MS-3). | ```object({ tenant = string environment = string component = string repo = string labels = optional(map(string), {}) allowed_environments = optional(list(string)) name_prefix = optional(string) })``` | n/a | yes |
| name | Logical name of this pool, unique within the component. Kebab-case. The pool id is <prefix>-<name>, where prefix is context.name_prefix or <tenant>-<environment>-<component>; the API limits it to 4-32 characters. | `string` | n/a | yes |
| oidc_providers | OIDC providers in the pool, keyed by provider id (4-32 characters of [a-z0-9-], not starting with gcp-). Each provider takes:   issuer_uri           https URL of the token issuer   attribute_mapping    Google attribute => CEL expression; must map google.subject   attribute_condition  CEL expression every token must satisfy; required and non-empty   allowed_audiences    accepted aud values (at most 10); empty means the provider's own resource name   jwks_json            the issuer's public JWKS, for an issuer Google cannot reach (a private cluster)   disabled             stops new token exchanges without deleting the provider A GitHub Actions issuer (https://token.actions.githubusercontent.com, or an enterprise issuer under it) must map attribute.repository_owner_id and reference assertion.repository_owner_id in its condition, so trust is pinned to the immutable numeric owner id. | ```map(object({ issuer_uri = string attribute_mapping = map(string) attribute_condition = string allowed_audiences = optional(list(string), []) jwks_json = optional(string) disabled = optional(bool, false) }))``` | n/a | yes |
| project_id | Project that owns the pool. | `string` | n/a | yes |
| enabled | Set false to create nothing. Every output is then null. | `bool` | `true` | no |
| name_override | Verbatim pool id, only for adopting a pool that predates the naming convention (ADR-0013). Leave null for new pools. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| pool_id | Short pool id (the last segment of pool_name). Null when the module is disabled. |
| pool_name | Full resource name of the pool: projects/<project-number>/locations/global/workloadIdentityPools/<pool-id>. Null when the module is disabled. |
| principal_sets | IAM member prefix per custom attribute mapped by any provider, keyed by the attribute name without 'attribute.': principalSet://iam.googleapis.com/<pool_name>/attribute.<name>/. Append the attribute value to get a member: the repository entry followed by acme/app matches that one repository. google.* mappings get no entry. |
| provider_names | Full resource name of each provider, keyed like var.oidc_providers: projects/<project-number>/locations/global/workloadIdentityPools/<pool-id>/providers/<key>. This is the value CI takes as workload_identity_provider. |
<!-- END_TF_DOCS -->
