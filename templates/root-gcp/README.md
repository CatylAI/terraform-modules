# templates/root-gcp

The consumer root template (module-standard MS-11, ADR-0003). Copy this directory into a repo as
`terraform/<component>/`, then:

1. Set `envs/common.tfvars`: your organisation's `allowed_tenants`, plus tenant, component and
   repo.
2. Write one `envs/<env>.tfvars` and one `envs/<env>.gcs.tfbackend` per environment. The backend
   prefix is `<repo>/<component>/<env>`.
3. Give the stack its own service account, scoped by IAM condition to its state prefix.
4. Replace the example module call in `main.tf`. Commit `.terraform.lock.hcl` after the first
   `init`.

Always go through the script:

```bash
scripts/tf.sh uat plan                       # writes uat.tfplan
scripts/tf.sh uat plan -detailed-exitcode    # exit 0 no changes, 2 changes, 1 error
scripts/tf.sh uat apply                      # CI only; TF_BREAK_GLASS=1 for a recorded exception
scripts/tf.sh uat apply ci.tfplan            # apply a named plan file
```

| Exit | Meaning |
|---|---|
| 0, 1, 2 | Terraform's own (2 = changes, with `-detailed-exitcode`) |
| 64 | Usage: unknown environment, a missing envs file, an unknown command |
| 78 | Unsafe configuration: refused before Terraform runs |
| 77 | Apply refused: outside CI, or no saved plan |

`TF_BACKEND_IMPERSONATE_SA` overrides the backend's service account. CI sets it to the stack's
own service account.

`tf.sh` refuses to run when:

- a local `terraform.tfstate` exists (a partial backend fell back to local state)
- the backend prefix does not end in `/<env>`
- `environment` is set in a tfvars file
- `apply` is run outside CI without the break-glass variable

Overrides layer as `common.tfvars`, then `<env>.tfvars`. The later file replaces a whole
variable, not nested keys. So keep root variables small, as `uploads_bucket` is here, and let the
module's optional attributes carry the defaults.
