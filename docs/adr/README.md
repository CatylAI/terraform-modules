# Architecture decision records

## Conventions (lib-platform's, verbatim in substance)

- One file per decision: `NNNN-short-slug.md`, four digits. Numbers are never reused.
- Status is one of `Proposed`, `Accepted`, `Superseded by ADR-NNNN`. The file's status line
  matches its row here.
- An ADR is added or amended **in the same change as the code**.
- Another repository's ADR is cited with that repository's name (`lib-platform ADR-0003`).
- CI is cited by job name, never by file and line number.
- Superseded text moves to `docs/adr/archive/`; it is never deleted.
- A deviation from `docs/spec/module-standard.md` is a decision. A chosen deviation names who
  signed it off.

## Index

| ADR | Title | Status |
|---|---|---|
| [0001](0001-monorepo-per-module-tags.md) | One repository for every module; one release-please component and tag per module | Accepted |
| [0002](0002-environment-enum-from-lib-platform.md) | The environment enum is lib-platform's: local, test, dev, uat, staging, prod | Accepted |
| [0003](0003-one-root-env-tfvars-no-terragrunt.md) | One root per component, environments as tfvars and backend files; no Terragrunt, no workspaces | Accepted |
| [0004](0004-gcp-first-aws-deferred.md) | v1 covers GCP, GitHub and Google Workspace; AWS modules wait for a live consumer | Accepted |
| [0005](0005-trivy-over-checkov.md) | trivy is the security scanner | Accepted |
| [0006](0006-secrets-by-reference.md) | Modules never take a secret value; secrets are references or write-only arguments | Accepted |
| [0007](0007-version-policy.md) | Version floors with major caps in modules; exact pins in roots | Accepted |
| [0008](0008-module-input-contract.md) | Every module takes context, name and enabled; groups are optional-attribute objects | Accepted |
| [0009](0009-ci-from-actions-library.md) | CI workflows come from the shared GitHub Actions library | Accepted, amended by ADR-0014 |
| [0010](0010-supersedes-prior-standards.md) | This standard supersedes the four prior Terraform documents | Accepted |
| [0011](0011-deletion-protection-without-variable-prevent-destroy.md) | Data protection uses provider-native deletion settings; prevent_destroy is literal only | Accepted |
| [0012](0012-internal-change-bumps-dependents.md) | A change to _internal bumps every dependent module through .context-digest | Accepted |
| [0013](0013-name-override-for-adoption.md) | name_override exists only to adopt existing resources with zero diff | Accepted |
| [0014](0014-public-distribution.md) | The repository is public, with its own CI; registry mirrors are a later option | Accepted |
| [0015](0015-scale-and-cost-defaults.md) | Safety is a default, capacity is an input; accumulating data has bounded retention | Accepted |
