# terraform-modules

Opinionated Terraform modules that are secure by default, typed end to end, and configured from
tfvars. Every module follows one standard,
[`docs/spec/module-standard.md`](docs/spec/module-standard.md):

- **One input shape.** `context`, `name` and `enabled` lead every module. Settings come in typed
  groups whose optional attributes carry production-safe defaults, so you override one attribute
  and keep the rest.
- **Secure by default, and parity by construction.** Encryption, deletion protection, private
  access and least-privilege IAM are the defaults. Modules never branch on the environment, so
  dev and prod run the same code and differ only in tfvars.
- **Startup to growth.** Safety is a default; capacity is an input. Nothing reserves capacity by
  default, and anything that accumulates data expires by default. Growing is a tfvars change, not
  a module swap.
- **Public-ready.** No organisation-specific values. Your tenants, environments and naming are
  inputs.

## Modules

| Module | Purpose | Tag prefix |
|---|---|---|
| [`gcp/gcs-bucket`](modules/gcp/gcs-bucket) | Cloud Storage bucket: uniform access, public access prevention, versioning with bounded retention, soft delete, deletion protection | `gcp-gcs-bucket-v` |

Each module is released on its own tag. Pin it:

```hcl
module "uploads" {
  source = "git::https://github.com/CatylAI/terraform-modules.git//modules/gcp/gcs-bucket?ref=gcp-gcs-bucket-v0.1.0"
  # ...
}
```

Keep the `//` subdirectory form. Modules share `modules/_internal/context` by relative path, and
that resolves only when the whole repository is the downloaded package.

## Using them in a root

[`templates/root-gcp`](templates/root-gcp) is the root layout the modules are designed for:

- one root per component
- `envs/common.tfvars` plus `envs/<env>.tfvars` and `envs/<env>.gcs.tfbackend` per environment
- `scripts/tf.sh <env> plan|apply`, which refuses the configurations that quietly do damage

## Contributing

```bash
scripts/gate.sh          # everything CI runs
scripts/gate.sh --fix    # fmt, README docs and context digests, then check
```

The gate needs Terraform at the version in `.terraform-version` (tfenv reads it), plus tflint,
trivy and terraform-docs. `scripts/install-tools.sh` installs pinned, checksum-verified versions on
Linux.

Conventional Commits, scoped to the module: `feat(gcp-gcs-bucket): ...`. Decisions live in
[`docs/adr/`](docs/adr/README.md). A decision or a deviation from the standard gets an ADR in the
same change.

## Not yet verified

- **Fetching the modules.** The `git::` source with a real release tag is proven only against a
  local clone, not yet against GitHub. The repository is not pushed.
- **Integration tests** (`command = apply`, MS-9.3) do not exist yet. They need a sandbox project.
  Unit tests use `mock_provider` and prove the configuration, not GCP's acceptance of it.
- **Release and CI workflows** have not run. release-please's handling of these per-module
  prefixed tags is configured from its documentation, and has not been exercised.
- **Dependabot and prefixed tags.** Whether Dependabot bumps prefixed module tags in consumers is
  unknown (ADR-0007).
- **Contract parity in CI.** The environment contract is checked against its source, the
  platform library's contract, only locally when `PLATFORM_LIBS_DIR` is set (ADR-0002).
- **Integration tests.** No sandbox project exists yet. The billing account is at its project
  limit.
- **Running the gate.** It has run on macOS (bash 3.2, Terraform 1.16.4). It has not run on the
  CI image.
