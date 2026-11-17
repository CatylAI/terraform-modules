# ADR-0007: Version floors with major caps in modules; exact pins in roots

Status: Accepted
Decided by: plan approval, 2026-11-17

## Context

Four documents disagreed: aws `~> 5.40`, `>= 5.40, < 6`, `>= 6.27, < 7` and `~> 6.0`.
One stack sits on google `~> 6.0` while everything else is on `~> 8.3`.
Another had lower bounds with no cap.

## Decision

- Modules use `required_version = ">= 1.14, < 2.0"` and providers `>= <floor>, < <next major>`
  (MS-7.1).
- Roots pin the exact CLI in `.terraform-version`, use `~>` for providers, and commit the lock
  file.
- Module tags in consumers are bumped by a bot. Dependabot is the first choice, because the estate
  already uses it. Whether it handles prefixed tags is unverified, and the fallback is Renovate with
  `extractVersion`.

## Consequences

- A module never forces a consumer onto a new major provider; a new major is a deliberate module
  release.

## Alternatives

`~>` in modules was rejected because it over-constrains consumers combining several modules.
