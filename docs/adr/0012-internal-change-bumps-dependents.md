# ADR-0012: A change to _internal bumps every dependent module through .context-digest

Status: Accepted
Decided by: Shawn LoPresto, 2026-11-17 (proposed by the lead)

## Context

release-please bumps a component only when a commit touches its path. A fix in
`_internal/context` would change the behavior of every module without releasing any of them.

## Decision

- Each module holds `.context-digest`, the SHA-256 of the `_internal/context` tree.
- The gate fails while any digest is stale.
- `python3 scripts/check_invariants.py --write-digests` refreshes them. The resulting change
  touches every dependent module, so release-please bumps each one.

## Consequences

- An `_internal` change cannot merge without releasing its dependents.
- The commit message for the digest refresh decides the bump size for every dependent. A
  breaking `_internal` change is a `feat!` and forces a major everywhere, which is correct.

## Alternatives

release-please `linked-versions` was rejected: it would lock every module to one version
(see ADR-0001).
