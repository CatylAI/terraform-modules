# The CatylAI Terraform module standard

Status: binding, for every module in this repository and every root that consumes one. It
supersedes the owning organisation's earlier Terraform standards (ADR-0010). Where this file and an ADR disagree, the ADR is the newer
decision and this file is amended in the same change.

Each rule has an id (`MS-n.m`). The gate, ADRs and review comments cite rules by id. A rule
marked **[gate]** is enforced by `scripts/gate.sh`. A rule marked **[test]** is enforced by each
module's `terraform test` suite. A rule with no mark is enforced in review, and should become
**[gate]** when someone finds a way.

---

## MS-1 Scope and shape

- **MS-1.1** A module is reusable resource logic with no environment knowledge. It has no
  backend, no state and no `provider` block. **[gate]**
- **MS-1.2** Modules live at `modules/<provider>/<name>/`. `<provider>` is one of `gcp`, `github`,
  `gws`, `aws`. `<name>` is kebab-case and names the thing, not the provider
  (`gcs-bucket`, not `google-storage-bucket`).
- **MS-1.3** `modules/_internal/` holds modules that other modules call and consumers never
  source directly. They are not released on their own (MS-10.4).
- **MS-1.4** Every module has, at minimum: `versions.tf`, `variables.tf`, `main.tf` (or files
  split by feature), `outputs.tf`, `README.md`, `tests/*.tftest.hcl`, `examples/minimal/`,
  `examples/complete/` and `.context-digest`. `_internal` modules need no examples and no
  digest. **[gate]**
- **MS-1.5** A module is built only for a named consumer: one that is live, or one whose root is
  built in the same wave, alongside the module. Speculative modules are not merged (ADR-0004).

## MS-2 Inputs

- **MS-2.1** Every variable has a `type` and a `description`. `any`, `map(any)` and
  `list(any)` are forbidden. A documented passthrough that truly needs `any` takes an ADR.
  **[gate]**
- **MS-2.2** Every module's first three inputs are `context`, `name` and `enabled`, in that
  order and with these exact types:

  ```hcl
  variable "context" {
    description = "Who and where, supplied by the calling root (module-standard MS-3)."
    type = object({
      tenant               = string
      environment          = string
      component            = string
      repo                 = string
      labels               = optional(map(string), {})
      allowed_environments = optional(list(string))
      name_prefix          = optional(string)
    })
    nullable = false
  }

  variable "name" {
    description = "Logical name of this instance, unique within the component. Kebab-case."
    type        = string
  }

  variable "enabled" {
    description = "Set false to create nothing. Every output is then null."
    type        = bool
    default     = true
    nullable    = false
  }
  ```

  `context` is validated once, inside `_internal/context` (MS-3). A module does not re-validate
  it.
- **MS-2.3** `name_override` (`string`, default `null`) is the only way to break the naming
  convention. It exists to adopt resources whose names predate this standard, with zero
  diff (ADR-0013). New resources leave it null.
- **MS-2.4** Inputs that a caller must decide have **no default**: anything that differs
  between environments or deployments, such as project IDs, locations, sizes and images.
  A forgotten value must fail at plan time, not quietly pick something.
- **MS-2.5** Related settings are grouped into one `object` with `optional(type, default)`
  attributes, `default = {}` and `nullable = false`. The caller overrides one attribute and keeps
  the secure default for the rest. Loose `enable_x` scalars are not used; the group carries its
  own `enabled`.

  ```hcl
  variable "versioning" {
    description = "Object versioning. Keeps prior generations so an overwrite or delete is recoverable."
    type = object({
      enabled = optional(bool, true)
    })
    default  = {}
    nullable = false
  }
  ```

- **MS-2.6** Collections that drive `for_each` or `dynamic` blocks are `map(object(...))` keyed
  by a stable, human-chosen name. They are never lists. Inserting a list element shifts every
  later index and forces replacement.
- **MS-2.7** Use a `validation` block for any constraint you would otherwise write in a comment:
  enums, formats, ranges, and rules across attributes. The error message names the input and
  the rule, never the offending value if it could be sensitive (the same rule as lib-platform
  B.2). **[test]**: every validation has an `expect_failures` run.
- **MS-2.8** `nullable = false` is set on every variable with a non-null default, so a caller
  passing `null` gets the default rather than a crash.

## MS-3 Context, naming and labels

- **MS-3.1** Every module calls `../../_internal/context` exactly once, as
  `module "context"`, and takes its name and labels from it. **[gate]**
- **MS-3.2** `_internal/context` validates the inputs. **[test]**
  - `tenant`: kebab-case. Any tenant is accepted. Which tenants an organisation allows is the
    root's policy (MS-15.2).
  - `environment`: one of `allowed_environments`. When that is null, the list is
    `contracts/environments.v1.json` `environments`. **[gate]** checks the default literal
    against the contract.
  - `component`: kebab-case.
  - `repo`: a repository name.
  - `name`: kebab-case.
  - User label keys: valid GCP label keys, and none of the reserved keys.
- **MS-3.3** The resource name of a GCP module is `<prefix>-<name>`. GitHub modules use
  `var.name` verbatim and apply no labels (ADR-0016). The prefix is `context.name_prefix` when the
  caller sets it, otherwise `<tenant>-<environment>-<component>`. `name_override` replaces the
  whole name, for adoption only (MS-2.3). A module states any length limit its resource type imposes, as a
  `precondition` on the resource.
- **MS-3.4** Every labelable resource gets `module.context.labels`. That map holds the caller's
  `context.labels` plus the reserved keys `managed-by=terraform`, `tenant`, `environment`,
  `component`, `repo` and `module`. Reserved keys win over caller keys. Values are lowercased and
  sanitized to GCP label rules. **[test]**
- **MS-3.5** No module branches on `context.environment`. Environment differences are expressed
  only as input values in the root's tfvars. This is what makes parity structural rather than
  aspirational. **[gate]**: no reference to `context.environment` outside `_internal/context`.

## MS-4 Enablement and dynamic blocks

- **MS-4.1** A singleton resource uses `count = var.enabled ? 1 : 0`. A collection uses
  `for_each = var.enabled ? var.x : {}`. **[test]**: a run with `enabled = false` asserts zero
  resources.
- **MS-4.2** Outputs read singletons through `one(resource.x[*].attr)`, so a disabled module
  yields `null` rather than an index error.
- **MS-4.3** Repeated nested blocks are `dynamic` over a `map(object)` (MS-2.6). An optional
  nested block that appears zero or one times is `dynamic` over
  `var.x.enabled ? [var.x] : []`.

## MS-5 Secure by default, and the override rule

- **MS-5.1** Every default is the production-grade value: encrypted, private, versioned,
  backed up, deletion-protected, logged. A cheaper or looser setting is an explicit override in
  the root's tfvars, where review sees it.
- **MS-5.2** **The override rule.** A knob exists for what a deployment legitimately differs
  on. There is no knob for an invariant (MS-6).
- **MS-5.3** A dangerous but legitimate opening needs an object whose `enabled = true` is
  accepted only with a `justification` of at least 20 characters, enforced by validation. A
  public bucket and a public ingress are the two known cases. The justification is written into
  the resource's description where the resource has one. Where it has none (a GCS bucket), the
  module sets a `public-access=true` label so the opening is findable, and the justification
  stays in the root's tfvars, where review sees it. **[test]**
- **MS-5.4** `lifecycle.prevent_destroy` must be a literal; Terraform cannot drive it from a
  variable. Modules therefore protect data with provider-native settings, which a variable *can*
  drive, defaulted on (ADR-0011):
  - `deletion_policy = "PREVENT"` where the resource offers it (GCS buckets from google 8.3),
    and `deletion_protection = true` where it offers that instead (Cloud SQL, Cloud Run v2).
  - Every module exposes this as `deletion_protection = { enabled = optional(bool, true) }`, so
    the knob reads the same in every module.
  - Literal `prevent_destroy = true` is used only on resources with neither setting whose loss
    is unrecoverable and which are never torn down per environment (DNS zones, WIF pools, state
    buckets).

## MS-6 Invariants (no knob, ever)

1. No module creates a service-account key or any long-lived credential. **[gate]**: grep for
   `google_service_account_key`.
2. No module accepts a secret value as an input. Secrets are passed as Secret Manager
   references (`projects/<p>/secrets/<s>`), or set through write-only arguments where the
   provider offers them (ADR-0006). **[gate]**: no variable named `*password*`, `*secret*` or
   `*token*` unless typed as a reference and described as one.
3. IAM inputs reject `roles/owner`, `roles/editor` and `roles/viewer`. **[test]**
4. IAM inputs reject `allUsers` and `allAuthenticatedUsers`. Public access goes only through
   MS-5.3. **[test]**
5. No `provider` blocks in modules. **[gate]**
6. No branching on `context.environment` (MS-3.5). **[gate]**
7. Labels are always applied (MS-3.4). **[test]**

## MS-7 Versions

- **MS-7.1** Modules declare floors with a major cap:
  - `required_version = ">= 1.14, < 2.0"`
  - `google >= 8.3, < 9.0`
  - `github >= 6.13, < 7.0`
  - `googleworkspace >= 0.7, < 1.0`
- **MS-7.2** Roots pin the exact CLI in `.terraform-version` (1.16.4 today), constrain each
  provider with `~>`, and commit `.terraform.lock.hcl`.
- **MS-7.3** Modules and their examples do not commit lock files; the consumer's lock file is the
  one that matters. **[gate]** through `.gitignore`.

## MS-8 Outputs

- **MS-8.1** An output is an API. Every output has a `description`. **[gate]**
- **MS-8.2** Export the attributes consumers use, never whole resource objects.
- **MS-8.3** `sensitive = true` on anything that would leak in a CI log. That only redacts the CLI
  output; the value is still in state.
- **MS-8.4** Values that applications read at runtime (12-factor IV) are published to Secret
  Manager or as service environment, not consumed through `terraform_remote_state`.

## MS-9 Testing and static checks

- **MS-9.1** Every module has unit tests under `tests/` using `mock_provider`, so no
  credentials are needed. At minimum they cover:
  1. secure defaults asserted attribute by attribute
  2. `enabled = false` creates nothing
  3. every validation fails on bad input (`expect_failures`)
  4. naming and labels
  5. every MS-6 invariant the module's inputs could violate

  **[gate]** runs them.
- **MS-9.2** `examples/minimal` shows the smallest correct call. `examples/complete` exercises
  every input group. Both must pass `terraform validate`. **[gate]**
- **MS-9.3** Integration tests (`command = apply`) run against the sandbox project, nightly and
  on release PRs. They are not part of the local gate. Until the sandbox exists, this is listed
  under "Not yet verified".
- **MS-9.4** `trivy config` runs over every module. Each suppression in `.trivyignore.yaml` is scoped to paths and carries a
  comment naming the rule, why it does not apply, and where the control lives instead. **[gate]**
- **MS-9.5** `tflint` runs with the terraform ruleset `all` preset and the google ruleset.
  **[gate]**
- **MS-9.6** The README block between `BEGIN_TF_DOCS` and `END_TF_DOCS` is generated by
  terraform-docs and must not drift. **[gate]**

## MS-10 Releases and consumption

- **MS-10.1** Each module is a release-please component tagged
  `<provider>-<name>-vX.Y.Z`, for example `gcp-gcs-bucket-v1.4.0` (ADR-0001). **[gate]**: every
  module has a package entry in `release-please-config.json`.
- **MS-10.2** Consumers pin the tag:
  `git::https://github.com/CatylAI/terraform-modules.git//modules/gcp/gcs-bucket?ref=gcp-gcs-bucket-v1.4.0`.
  `ref=main` and branch refs are forbidden.
- **MS-10.3** A module stays `0.x` until its first consumer migrates onto it with a zero-diff
  plan, then cuts `1.0.0`. A breaking change after that is a major release, and its
  `CHANGELOG.md` entry carries the migration, including `moved` blocks.
- **MS-10.4** A change under `modules/_internal/` changes the behavior of every module that
  calls it, but release-please only bumps the packages whose paths changed. Each module
  therefore holds `.context-digest`, the SHA-256 of the `_internal/context` tree. The gate
  fails while any digest is stale. Refreshing the digests touches every dependent module, so
  release-please bumps each one (ADR-0012). **[gate]**
- **MS-10.5** Commits follow Conventional Commits with the module as scope:
  `feat(gcp-gcs-bucket): ...`.

## MS-11 Roots (consumers)

These rules govern root modules in consumer repos. `templates/root-gcp/` implements them.

- **MS-11.1** One root per component. Environments differ only by
  `envs/common.tfvars` + `envs/<env>.tfvars` + `envs/<env>.gcs.tfbackend`. No workspaces, no
  Terragrunt, no per-environment `main.tf` (ADR-0003).
- **MS-11.2** The environment comes from exactly one place: the CLI argument to `scripts/tf.sh`,
  passed as `-var environment=<env>`. tfvars do not set it, so a tfvars file can never disagree
  with the backend it is planned against.
- **MS-11.3** `tf.sh` refuses to run in these cases:
  - a local `terraform.tfstate` exists (a partial backend has silently fallen back to local
    state)
  - the backend prefix does not end in `/<env>`
  - `apply` is run outside CI, without the break-glass variable set

  Its own exit codes (64 usage, 78 unsafe configuration, 77 apply refused) never collide with
  Terraform's 0, 1 and 2, so `plan -detailed-exitcode` passes through. This interface is
  shared with the actions library's Terraform stack workflow; change both together. **[gate]**
  (`scripts/test_tf_sh.sh`)
- **MS-11.4** State lives in a GCS bucket under the prefix `<repo>/<component>/<env>`. It is read
  and written by the stack's own service account, which an IAM condition limits to that prefix.
- **MS-11.5** Roots set the provider's `default_labels` from the same context, so resources
  written inline in a root are labeled too.

## MS-12 Twelve-factor mapping

| Factor | How the standard delivers it |
|---|---|
| I Codebase | One root per component; environments differ only in tfvars (MS-11.1) |
| II Dependencies | Exact CLI, committed lock file, module tags (MS-7, MS-10) |
| III Config | Non-secret config in tfvars; secrets by reference (MS-6.2); workload modules split `env` from `secret_env` |
| IV Backing services | Data modules publish connection references for apps to read (MS-8.4) |
| V Build, release, run | Images are inputs supplied by CI or tfvars, never hardcoded in `main.tf` |
| VI–VIII Processes, port binding, concurrency | Workload modules take `container_port` and a `scaling` group; stateless by construction |
| IX Disposability | Startup and liveness probes on by default, on lib-platform's `/health` and `/health?deep=true` |
| X Dev/prod parity | Same root, same modules, same defaults; no environment branching (MS-3.5) |
| XI Logs | Workloads log to stdout and stderr, collected by Cloud Logging; sink and retention modules |
| XII Admin processes | One-off work runs as a job module, never by hand |

## MS-13 Architecture Framework section

Every module README ends with an "Architecture Framework" section. It maps the module's defaults
to the six pillars:

- security
- reliability
- cost optimization
- operational excellence
- performance
- sustainability

It names each default and the pillar it serves, and states which defaults trade one pillar
against another. Today that means the Google Cloud Architecture Framework. AWS Well-Architected
applies to `modules/aws/` when it is used.

## MS-14 Scale and cost: from startup to growth without a rewrite

- **MS-14.1** Safety is a default; capacity is an input. Encryption, deletion protection,
  backups and private networking are on by default at every scale (MS-5). Anything that
  reserves capacity or multiplies cost has a default of the smallest correct value, and growth is
  reached by changing inputs in tfvars, never by changing or replacing a module. That includes
  minimum instances, high-availability replicas, machine tiers, committed throughput and
  regional redundancy.
- **MS-14.2** A module never reserves capacity by default. A minimum instance count above zero,
  an HA standby or a second region is an explicit input, and the module's README states its cost
  shape.
- **MS-14.3** Every default that accumulates data has a bounded retention by default:
  noncurrent object versions, soft-deleted objects, logs, backups and images. An unbounded
  setting is allowed only as an explicit override (for example `noncurrent_retention_days = 0`).
  **[test]**
- **MS-14.4** Growth paths are tested. A module's `examples/complete` and tests include the
  growth-scale settings (HA, CMEK, larger tiers), so the path from the minimal call to the large
  one is exercised before anyone needs it.
- **MS-14.5** Every module's README has a "Cost shape" line: what is billed, what drives it, and
  which input changes it.

## MS-15 Public-ready

Modules are published publicly (ADR-0014). Nothing in a module may assume CatylAI.

- **MS-15.1** No organisation-specific value in module code, tests or examples: no organisation
  names, project ids, domains, emails, account ids or repository names. Examples use
  `acme`, `example.com` and similar. The one allowed string is this repository's own source URL.
  Across the whole repository, the gate also rejects the owning organisation's infrastructure
  identifiers: projects, buckets, runners and internal repositories. **[gate]**
- **MS-15.2** An organisation's policy lives in its roots, not its modules: which tenants exist,
  which environments are allowed, and which regions are permitted. `templates/root-gcp` shows
  CatylAI's policy as root-level validation.
- **MS-15.3** Everything a different organisation would reasonably change is an input with a
  sensible default: the environment vocabulary, the name prefix, labels, locations and sizes.
- **MS-15.4** README examples and `examples/` must work for a stranger who has only the README:
  no reference to internal documents or repositories in the usage path.
