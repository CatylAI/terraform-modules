# ADR-0009: CI workflows come from the shared GitHub Actions library

Status: Accepted, amended by ADR-0014
Decided by: Shawn LoPresto, 2026-11-17

## Context

The plan first put the reusable Terraform stack and `github-config` workflows here. They are
copied far beyond Terraform: `github-config.yml` is in 7 repos, 1,854 lines in total.

## Decision

- Reusable workflows and composite actions live in a dedicated actions library, designed and
  released on its own. Consumer roots use its Terraform stack workflow.
- Amended by ADR-0014: the library is private and this repository is public, so this repository
  keeps its own `ci.yaml` and `release.yaml`, which call `scripts/gate.sh` and release-please
  directly. They do not switch to the library.

## Consequences

- Consumer migrations (wave 1 onward) depend on the library's first release. This repository's
  CI does not.
- `ci.yaml` installs its own pinned, checksum-verified tools.

## Alternatives

Keeping the workflows here was rejected: non-Terraform repos would depend on a Terraform module
repo for their CI.
