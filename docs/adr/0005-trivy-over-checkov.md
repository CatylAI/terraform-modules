# ADR-0005: trivy is the security scanner

Status: Accepted
Decided by: plan approval, 2026-11-17

## Context

The AWS-era repos documented checkov. The live GCP estate's CI runs
trivy and keeps a `.trivyignore` whose entries carry their reasons.

## Decision

- The gate runs `trivy config` over `modules/` with exit code 1 on findings.
- Each suppression in `.trivyignore` names the rule, why it does not apply, and where the
  control lives instead (MS-9.4).

## Consequences

- One scanner across the live estate; findings and suppressions read the same in every repo.

## Alternatives

Running both was rejected: two rule sets with overlapping ids double the suppression
bookkeeping for little extra coverage.
