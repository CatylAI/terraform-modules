# ADR-0001: One repository for every module; one release-please component and tag per module

Status: Accepted
Decided by: Shawn LoPresto, 2026-11-17

## Context

Two earlier attempts split modules differently.

- Nine single-module repositories each carried a byte-identical copy of the same CI, release and
  docs scaffolding. They inherited the same template bugs: an invalid CODEOWNERS, and a
  release-notes script that derived the wrong module name.
- A small monorepo used a single repo-wide version, so a breaking change to one module forced
  every consumer to review all of them.

The main consumer of the first attempt pinned tags that no longer existed after a repository
rename, so it could not `init`.

## Decision

- One repository, `CatylAI/terraform-modules`, holds every module under `modules/<provider>/<name>/`.
- release-please runs in monorepo mode with one component per module and
  `include-component-in-tag`, producing tags like `gcp-gcs-bucket-v1.4.0`. This mirrors
  lib-platform's `typescript-vX.Y.Z` (lib-platform ADR-0003).
- Consumers source `git::https://github.com/CatylAI/terraform-modules.git//modules/<provider>/<name>?ref=<tag>`.

## Consequences

- Scaffolding, CI and the gate exist once.
- A module's version moves only when that module (or `_internal`, see ADR-0012) changes.
- Consumers download the whole repository at a tag, which is what lets modules share
  `_internal/context` by relative path.
- Version constraints (`~> 1.4`) are not available over git sources; consumers pin exact tags and
  a bot bumps them (ADR-0007).

## Alternatives

A repo-wide single version was rejected for the review-everything cost above. The HCP Terraform
private registry was rejected: nothing in the estate uses HCP, it adds a SaaS dependency and a
second credential, and git tags already give immutable, reviewable pins.
