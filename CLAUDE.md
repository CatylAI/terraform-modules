# terraform-modules

Opinionated Terraform modules, one repository, one release-please component per module.

The binding standard is `docs/spec/module-standard.md`; rules are cited by id (`MS-n.m`).
Decisions are in `docs/adr/`. This repository is public (ADR-0014). CatylAI's internal wave plans
and organisation values live in CatylAI's private docs repository, under
`plans/terraform-modules/`. Never copy internal values back into this repository.

## The gate

```bash
scripts/gate.sh          # run before every push; CI runs exactly this
scripts/gate.sh --fix    # terraform fmt, terraform-docs, .context-digest refresh, then check
```

It runs, in order:

- tools and the exact Terraform version (`.terraform-version`)
- fmt
- invariants (`scripts/check_invariants.py`)
- tf.sh tests
- per-module `validate` and `terraform test` (mock providers)
- examples `validate`
- template `validate` against this checkout's modules
- tflint
- trivy
- terraform-docs drift

A missing tool fails the gate.

## Process rules (each enforced by the gate unless marked review)

1. **The standard rule.** Every module follows MS-1 to MS-15. A deviation is an ADR in the same
   change, naming who signed it off.
2. **The context rule.** A change under `modules/_internal/` refreshes every `.context-digest` in
   the same change, so every dependent module is released (ADR-0012).
3. **The contract rule.** `contracts/` is canonical JSON. The environment list there, the default
   in `_internal/context`, the template's validation and `tf.sh`'s case list are one value, held
   equal by the gate. lib-platform is the source (ADR-0002).
4. **The public rule.** No organisation value in `modules/` or `templates/`, and no internal
   identifier (project, bucket, service account, runner, internal repository) anywhere in the
   repository (MS-15.1). Examples use `acme` and `example.com`.
5. **The test rule.** Every validation has an `expect_failures` run. Every default has an
   assertion. Prove a new negative test by breaking the rule in a scratch copy, and watch the
   test fail. A failing `run` skips the runs after it, so fix the first failure first.
6. **The release rule.** Conventional Commits scoped to the module id (`gcp-gcs-bucket`). Every
   module has a `release-please-config.json` package. Never hand-edit `CHANGELOG.md` or the
   manifest.
7. **The tf.sh rule.** `templates/root-gcp/scripts/tf.sh` is an interface shared with the actions
   library's Terraform stack workflow: argument shape, `-var environment`, exit codes 64, 78 and
   77. Change both together. (review)

## Building a module

Copy `modules/gcp/gcs-bucket` as the reference implementation, then:

- set `module = "<provider>-<name>"` in the `context` call
- add a release-please package
- run `scripts/check_invariants.py --write-digests`
- write the tests before the resources
- read the provider schema (`terraform providers schema -json`) rather than recalling attribute
  names. For example, google 8.x types `retention_period` as a string, and lifecycle `action` and
  `condition` as sets.

## Conventions

Terraform 1.16.4 (tfenv). Module floors: `terraform >= 1.14, < 2.0`, `google >= 8.3, < 9.0`. Tool
pins are in `scripts/install-tools.sh`; each was at least two weeks old when chosen. CI runs on
GitHub-hosted runners only (ADR-0014).
