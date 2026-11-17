# ADR-0006: Modules never take a secret value; secrets are references or write-only arguments

Status: Accepted
Decided by: plan approval, 2026-11-17

## Context

The legacy rds, elasticache and service modules generated `random_password` and stored it in
state. One consumer already does the right thing: Terraform creates the Secret Manager container,
and a script syncs the value out of band.

## Decision

- A module accepts a secret only as a Secret Manager reference.
- Where the provider offers a write-only argument (`*_wo`), a module may accept an ephemeral value
  and pass it to that argument. The value is then never in plan or state. Each such use names the
  provider version that introduced the argument.
- `gcp/secret` creates the container and accessor IAM, never a version holding a value.

## Consequences

- No secret material sits in state in any new module.
- Seeding a secret value is a separate, recorded step outside Terraform.

## Alternatives

Generating values with `random_password` was rejected: state becomes a second copy of the
secret.
