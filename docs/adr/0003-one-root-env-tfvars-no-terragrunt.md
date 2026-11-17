# ADR-0003: One root per component, environments as tfvars and backend files; no Terragrunt, no workspaces

Status: Accepted
Decided by: Shawn LoPresto, 2026-11-17

## Context

Every layout in the existing estate caused a problem:

- One root kept three byte-identical `main.tf` files, one per environment directory.
- Another keeps one directory per environment, each with its own `main.tf`.
- Seven roots planned three environments against a single state key.
- One Terragrunt setup ended with unlocked state.

## Decision

- A root is one directory of `.tf` files. Each environment is `envs/<env>.tfvars` plus
  `envs/<env>.gcs.tfbackend`, layered over `envs/common.tfvars`.
- `scripts/tf.sh <env> <command>` is the only entry point. It passes the environment as
  `-var environment=<env>` (MS-11.2) and refuses the unsafe cases (MS-11.3).
- Workspaces are not used to separate environments. Terragrunt is not used.

## Consequences

- Code parity between environments is structural: there is one `main.tf`.
- An environment that genuinely needs a different set of resources expresses it as a module's
  `enabled` input in that environment's tfvars, which review sees.
- tfvars layering replaces whole variables, not nested keys. Roots therefore declare small,
  focused variables, and modules carry the defaults (MS-2.5).

## Alternatives

Directories per environment were rejected because their `main.tf` files drift.
Terragrunt was rejected as a tool none of the live repos use, which buys DRY backends at the cost
of a second configuration language. Workspaces were rejected because they share one backend
identity across environments (terraform-aws `terraform-standards`).
