# ADR-0004: v1 covers GCP, GitHub and Google Workspace; AWS modules wait for a live consumer

Status: Accepted
Decided by: Shawn LoPresto, 2026-11-17

## Context

The AWS estate was decommissioned on 2026-09-21. Only the DNS and organisation-management
accounts remain. Every
AWS consumer of the old modules targets a closed account.

## Decision

- v1 builds modules only for live consumers on GCP, GitHub and Google Workspace.
- `modules/aws/` exists, and this standard applies to it unchanged. A module there is built when
  a live AWS consumer needs it.
- The remaining Route 53 and Organizations resources stay out of scope, a known and recorded
  choice.

## Consequences

- Nothing is built that no running system exercises.
- The earlier AWS module repositories are archived, not ported.

## Alternatives

Full AWS parity was rejected: every module would ship unexercised, and an unexercised module is
an untested one.
