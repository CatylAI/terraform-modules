# ADR-0015: Safety is a default, capacity is an input; accumulating data has bounded retention

Status: Accepted
Decided by: Shawn LoPresto, 2026-11-17 (requirement: scale from startup through growth, cost-effective at any scale)

## Context

Production-grade defaults can mean two different things: safe, or large. Large defaults
(minimum instances, HA standbys, big tiers) make a startup pay growth-stage prices for an idle
system. Unbounded defaults (versions kept forever, logs never expiring) make cost grow with time
rather than use. The old bucket module enabled versioning with no expiry.

## Decision

MS-14 in full:
- Safety settings default on at every scale.
- Capacity and cost multipliers default to the smallest correct value and are raised in tfvars.
- No module reserves capacity by default.
- Every default that accumulates data has a bounded retention, overridable explicitly.
- Growth-scale settings are exercised in `examples/complete` and the tests.
- Every README states the module's cost shape.

## Consequences

- A startup deploys the minimal call and pays for usage, not reservations.
- Growth is a tfvars diff that review sees, such as `min_instances = 2` or `high_availability = true`.
  It is never a module swap or a state migration.
- `gcp/gcs-bucket` gains two default cost guards: noncurrent versions expire after 30 days, and
  incomplete multipart uploads are aborted after 1 day.

## Alternatives

Size presets (`profile = "startup" | "growth"`) were rejected for now: they hide individual
settings behind a name, and a preset that mentions the environment invites branching on it
(MS-3.5). This can be revisited if real modules accumulate many sizing inputs.
