# ADR-0014: The repository is public, with its own CI; registry mirrors are a later option

Status: Accepted
Decided by: Shawn LoPresto, 2026-11-17 (option a; proposed by the lead)

## Context

Requirement (2026-11-17): the modules must be parameterized enough to share as public
repositories. Four constraints follow:

1. **The registry's shape.** The public Terraform Registry publishes one module per repository,
   named `terraform-<provider>-<name>` and released on plain `vX.Y.Z` tags. That conflicts with
   this monorepo's prefixed tags (ADR-0001).
2. **Self-hosted runners.** GitHub advises against self-hosted runners on public repositories,
   because a pull request from a fork can run arbitrary code on the runner. The organisation's CI
   convention is a self-hosted runner.
3. **Internal planning documents.** These named internal projects, service accounts and
   repositories. MS-15.1 kept module code clean, but not those documents.
4. **The shared Actions library is private**, with Actions access limited to the organisation. A
   public repository cannot call its reusable workflows, so ADR-0009's thin-caller model cannot
   hold for this repository. Raised by the library's design session; not yet confirmed with a
   run.

Three CI options were put to Shawn:

- (a) public, with its own inline CI
- (b) public, with the library made public too
- (c) private

## Decision

Option (a):

- **Public.** This repository is public. Consumers, including the owning organisation, use git
  tags as in ADR-0001, and fetch modules anonymously over HTTPS.
- **Inline CI.** This repository keeps its own CI: `ci.yaml` and `release.yaml` call
  `scripts/gate.sh` and a pinned release-please directly. The shared library's workflows serve
  consumer roots only (ADR-0009, amended).
- **Runners.** CI runs on GitHub-hosted runners only. Integration tests that need cloud
  credentials (MS-9.3) run only on pushes to `main` and on schedules, never on pull requests
  from forks.
- **Docs.** Internal planning documents live in the organisation's private docs repository. This
  repository keeps the organisation-neutral spec and ADRs, and the gate scans every public file
  for internal identifiers (MS-15.1).
- **Later, on demand.** If registry publication is wanted, a release job splits each module into a
  read-only mirror, `terraform-google-<name>`. The job vendors `_internal/context` as
  `modules/context`, rewrites the relative source, and pushes a plain `vX.Y.Z` tag. The monorepo
  stays the only place changes are made.

## Consequences

- Consumer CI needs no token to `terraform init`. The library's module-fetch token step and its
  App-permission work drop out.
- This repository's CI differs from the organisation's runner convention. That is recorded here,
  not silently copied.
- Registry mirrors add a release job and N read-only repositories. They are not built until
  someone needs `registry.terraform.io` sources.

## Alternatives

- (b) was rejected: it would expose the whole CI library and require a public-ready review of
  it, for a benefit this repository does not need.
- (c) was rejected: it fails the public-sharing requirement.
- Per-module repositories from the start were rejected: they bring back the scaffolding
  duplication ADR-0001 removed.
