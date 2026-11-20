# ADR-0016: GitHub modules use names verbatim and carry no labels

Status: Accepted
Decided by: lead, 2026-11-20 (within MS-3, which the standard leaves GCP-shaped)

## Context

MS-3.3 names a resource `<prefix>-<name>`, and MS-3.4 applies labels. Both fit GCP. A GitHub
repository, environment or ruleset is named by the people who use it, and the name is part of
every clone URL, workflow reference and ruleset condition. Prefixing it with
`<tenant>-<environment>-<component>` would rename live repositories, and GitHub resources carry
no labels.

## Decision

- Modules under `modules/github/` still take `context`, `name` and `enabled`, and still call
  `_internal/context` (MS-3.1), so the inputs are validated and the shape stays the same
  everywhere.
- The GitHub resource name is `var.name` verbatim. `name_override` is not offered, because there
  is no computed name to override.
- `module.context.labels` is not applied: GitHub has no labels. A module may offer repository
  topics as an input; they are not derived from context.
- `context.environment` still must not drive behavior (MS-3.5). A GitHub environment's own name
  is an ordinary input (for example `production`), not `context.environment`.

## Consequences

- A GitHub module adopts a live repository by `import` with no rename. No `name_override` is
  needed.
- The gate's MS-3.1 check applies unchanged. MS-2.3's `name_override` requirement applies to
  modules that compute a name, which GitHub modules don't.

## Alternatives

Prefixing GitHub names was rejected: it would rename live repositories and break every reference
to them.
