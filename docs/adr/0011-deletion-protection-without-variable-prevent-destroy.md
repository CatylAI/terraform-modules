# ADR-0011: Data protection uses provider-native deletion settings; prevent_destroy is literal only

Status: Accepted
Decided by: Shawn LoPresto, 2026-11-17 (proposed by the lead)

## Context

`lifecycle { prevent_destroy = ... }` must be a literal. A module therefore cannot let an
environment choose it. The old template set it always, which makes teardown in a scratch
environment a state-surgery job. The usual workaround, two resource blocks with different
lifecycles, changes the resource address when the flag flips and forces replacement.

## Decision

- Protect data with the resource's own settings, which a variable can drive, defaulted on:
  - `deletion_policy = "PREVENT"` where the resource offers it. GCS buckets offer it from google
    8.3.0, the module floor; verified 2026-11-17 against the 8.3.0, 8.6.0, 8.9.0 and 8.11.0
    schemas.
  - `deletion_protection = true` where the resource offers that instead (Cloud SQL, Cloud Run v2).
- Every module exposes it the same way: `deletion_protection = { enabled = optional(bool, true) }`.
  Buckets add `force_destroy`, allowed only with protection off.
- Use literal `prevent_destroy = true` only for resources with neither setting that are never torn
  down per environment and whose loss is unrecoverable. Read the schema before choosing the
  literal.
- Amended 2026-11-20 (wave 1): workload identity pools offer `deletion_policy` from google 8.3.0
  (verified in the schema by the workload-identity-pool build), so they use the
  `deletion_protection` knob, not the literal. The original text listed them under the literal by
  mistake.

## Consequences

- `terraform destroy`, or an apply that would delete a protected resource, fails while the
  setting is in state. Teardown is a tfvars change, then an apply, then the destroy.
- Turning protection off in a non-prod environment is a tfvars change that shows in review.

## Alternatives

Two-block toggling was rejected because the address change forces replacement. Always-on
`prevent_destroy` was rejected because it makes per-environment teardown impossible without
state edits.
