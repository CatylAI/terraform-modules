# ADR-0008: Every module takes context, name and enabled; groups are optional-attribute objects

Status: Accepted
Decided by: plan approval, 2026-11-17

## Context

Across the old modules, the main resource was named `this` in some and `main` in others. They
used four tag schemes, hardcoded the `catylai` prefix in several places, used `""` and `null`
interchangeably, and barely used `optional()`.

## Decision

MS-2, MS-3 and MS-4 in full:
- `context`, `name` and `enabled` lead every module.
- `_internal/context` owns validation, naming and labels.
- Settings come in `optional()` groups with `default = {}` and `nullable = false`.
- Collections are maps keyed by stable names.
- The singleton resource is named `this`.

## Consequences

- A reader who knows one module can read any other.
- `_internal/context` is a shared dependency, so its releases are handled by ADR-0012.

## Alternatives

cloudposse's `null-label` was rejected: it is a general-purpose label engine with many knobs,
while the enum and the reserved keys here are fixed by contract.
