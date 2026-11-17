# ADR-0013: name_override exists only to adopt existing resources with zero diff

Status: Accepted
Decided by: Shawn LoPresto, 2026-11-17 (proposed by the lead)

## Context

Every live resource predates the naming convention. Migration requires a plan with 0 to add,
0 to change and 0 to destroy. Renaming a GCS bucket, a service account or a Cloud SQL instance is
destroy-and-create.

## Decision

- Each module takes `name_override` (nullable string).
- When set, it replaces the computed `<tenant>-<environment>-<component>-<name>` verbatim.
- Labels still apply.
- New resources leave it null.

## Consequences

- Adoption is a `moved` or `import` block plus `name_override` in the root.
- Review treats any new `name_override` on a resource that does not exist yet as a defect.

## Alternatives

Making the prefix optional per root was rejected: it would let new resources skip the
convention silently.
